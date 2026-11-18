# Run only in the existing protected CI environment; never writes or prints signing credentials.
require 'base64'
require 'json'
require 'jwt'
require 'net/http'
require 'openssl'
require 'uri'
require 'bigdecimal'

key = OpenSSL::PKey.read(Base64.decode64(ENV.fetch('ASC_KEY_CONTENT')))
token = JWT.encode({ iss: ENV.fetch('ASC_ISSUER_ID'), iat: Time.now.to_i, exp: Time.now.to_i + 900,
                     aud: 'appstoreconnect-v1' }, key, 'ES256', { kid: ENV.fetch('ASC_KEY_ID') })
CLIENT_TOKEN = token
APPLY = ENV.fetch('STORE_MODE', 'inspect') == 'prepare'
PRODUCT_ID = 'com.zhangyangbin.idvault.pro.lifetime'

def api(method, path, payload = nil, allow_missing: false)
  uri = URI(path.start_with?('https://') ? path : "https://api.appstoreconnect.apple.com#{path}")
  raise 'Unexpected API origin' unless uri.host == 'api.appstoreconnect.apple.com'
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request['Authorization'] = "Bearer #{CLIENT_TOKEN}"
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(payload) if payload
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) { |http| http.request(request) }
  return nil if allow_missing && response.code == '404'
  result = response.body.empty? ? {} : JSON.parse(response.body)
  unless response.is_a?(Net::HTTPSuccess)
    errors = result.fetch('errors', []).map { |e| [e['code'], e['detail'] || e['title']].join(': ') }
    raise "ASC #{method.upcase} #{uri.path} HTTP #{response.code}: #{errors.join('; ')}"
  end
  result
end

def all(path)
  rows = []
  loop do
    result = api('get', path)
    rows.concat(result.fetch('data'))
    path = result.dig('links', 'next')
    break unless path
  end
  rows
end

def link(type, id)
  { data: { type: type, id: id } }
end

app = all('/v1/apps?' + URI.encode_www_form('filter[bundleId]' => 'com.zhangyangbin.idvault')).first
raise 'IDVault App Store record not found' unless app
app_id = app.fetch('id')
puts "IDVault app record: #{app_id}"
products = all("/v1/apps/#{app_id}/inAppPurchasesV2?limit=200")
product = products.find { |p| p.dig('attributes', 'productId') == PRODUCT_ID }
if !product && APPLY
  product = api('post', '/v2/inAppPurchases', { data: { type: 'inAppPurchases', attributes: {
    name: 'IDVault Pro Lifetime', productId: PRODUCT_ID, inAppPurchaseType: 'NON_CONSUMABLE',
    familySharable: false, reviewNote: 'One-time purchase unlocks multiple members and unlimited documents. Free tier: 1 member and 10 documents. Existing records remain readable and exportable if entitlement changes. Documents and OCR remain on device.'
  }, relationships: { app: link('apps', app_id) } } }).fetch('data')
end
if product
  raise 'Existing product has unexpected type' unless product.dig('attributes', 'inAppPurchaseType') == 'NON_CONSUMABLE'
  id = product.fetch('id')
  puts "Product: #{PRODUCT_ID}; id=#{id}; state=#{product.dig('attributes','state')}"
  versions = all("/v2/inAppPurchases/#{id}/versions?limit=200")
  version = versions.find { |v| %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW REJECTED DEVELOPER_REJECTED].include?(v.dig('attributes','state')) }
  version ||= api('post', '/v1/inAppPurchaseVersions', { data: { type: 'inAppPurchaseVersions', relationships: { inAppPurchase: link('inAppPurchases', id) } } }).fetch('data') if APPLY && versions.empty?
  if version
    v_id = version.fetch('id')
    localizations = all("/v1/inAppPurchaseVersions/#{v_id}/localizations?limit=200")
    { 'zh-Hans' => ['拾页专业版', '一次买断，解锁多位家庭成员和不限数量资料。'],
      'en-US' => ['Shiye Pro', 'One-time purchase for multiple family members and unlimited documents.'] }.each do |locale, (name, description)|
      existing = localizations.find { |l| l.dig('attributes', 'locale') == locale }
      attributes = { name: name, description: description }
      if APPLY
        if existing
          api('patch', "/v2/inAppPurchaseLocalizations/#{existing['id']}", { data: { type: 'inAppPurchaseLocalizations', id: existing['id'], attributes: attributes } })
        else
          api('post', '/v2/inAppPurchaseLocalizations', { data: { type: 'inAppPurchaseLocalizations', attributes: attributes.merge(locale: locale), relationships: { version: link('inAppPurchaseVersions', v_id) } } })
        end
      end
    end
    puts "Editable product version: #{v_id}; state=#{version.dig('attributes','state')}; existing_localizations=#{localizations.size}"
  end
  points = all("/v2/inAppPurchases/#{id}/pricePoints?" + URI.encode_www_form('filter[territory]' => 'CHN', 'limit' => '8000'))
  point = points.find { |p| BigDecimal(p.dig('attributes','customerPrice')) == BigDecimal('18') }
  raise 'No exact CNY 18 price point; refusing to substitute a price' unless point
  schedule = api('get', "/v2/inAppPurchases/#{id}/iapPriceSchedule", allow_missing: true)
  if APPLY && schedule.nil?
    temporary_price = '${price18}'
    api('post', '/v1/inAppPurchasePriceSchedules', {
      data: { type: 'inAppPurchasePriceSchedules', relationships: {
        inAppPurchase: link('inAppPurchases', id), baseTerritory: link('territories', 'CHN'),
        manualPrices: { data: [{ type: 'inAppPurchasePrices', id: temporary_price }] }
      } },
      included: [{ type: 'inAppPurchasePrices', id: temporary_price, attributes: { startDate: nil },
        relationships: { inAppPurchaseV2: link('inAppPurchases', id), inAppPurchasePricePoint: link('inAppPurchasePricePoints', point.fetch('id')) } }]
    })
    schedule = api('get', "/v2/inAppPurchases/#{id}/iapPriceSchedule")
  end
  if schedule
    schedule_id = schedule.fetch('data').fetch('id')
    base = api('get', "/v1/inAppPurchasePriceSchedules/#{schedule_id}/baseTerritory").dig('data', 'id')
    manual = api('get', "/v1/inAppPurchasePriceSchedules/#{schedule_id}/manualPrices?" + URI.encode_www_form('filter[territory]' => 'CHN', 'include' => 'inAppPurchasePricePoint', 'limit' => '200'))
    prices = manual.fetch('included', []).select { |p| p['type'] == 'inAppPurchasePricePoints' }.map { |p| p.dig('attributes','customerPrice') }
    puts "Price schedule: base=#{base}; CHN customer prices=#{prices.inspect}"
    raise 'Existing schedule differs from approved CNY 18 price; review required' unless base == 'CHN' && prices.any? { |p| BigDecimal(p) == BigDecimal('18') }
  else
    puts 'Price schedule: missing (inspect only)'
  end
  availability = api('get', "/v2/inAppPurchases/#{id}/inAppPurchaseAvailability", allow_missing: true)
  if APPLY && availability.nil?
    territories = all('/v1/territories?limit=200')
    availability = api('post', '/v1/inAppPurchaseAvailabilities', { data: { type: 'inAppPurchaseAvailabilities', attributes: { availableInNewTerritories: true }, relationships: {
      inAppPurchase: link('inAppPurchases', id), availableTerritories: { data: territories.map { |t| {type: 'territories', id: t.fetch('id')} } }
    } } })
  end
  puts "Purchase availability configured: #{!availability.nil?}"
else
  puts 'Lifetime product: not created (inspect only)'
end

versions = all("/v1/apps/#{app_id}/appStoreVersions?" + URI.encode_www_form('filter[platform]' => 'IOS', 'limit' => '200'))
versions.each do |v|
  puts "App version #{v.dig('attributes','versionString')}: #{v.dig('attributes','appStoreState')}"
  locales = all("/v1/appStoreVersions/#{v['id']}/appStoreVersionLocalizations?limit=200")
  locales.each do |l|
    a = l.fetch('attributes')
    presence = %w[description keywords supportUrl].to_h { |f| [f, !a[f].to_s.empty?] }
    screenshots = all("/v1/appStoreVersionLocalizations/#{l['id']}/appScreenshotSets?limit=200")
    puts "Store listing #{a['locale']}: #{presence}; screenshot_sets=#{screenshots.size}"
  end
end
puts 'No review submission or automatic release was triggered.'
