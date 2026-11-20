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
  result = response.body.to_s.empty? ? {} : JSON.parse(response.body)
  unless response.is_a?(Net::HTTPSuccess)
    collect_errors = lambda do |node|
      case node
      when Hash
        own = node.key?('code') ? [[node['code'], node['detail'] || node['title']].join(': ')] : []
        own + node.values.flat_map { |value| collect_errors.call(value) }
      when Array
        node.flat_map { |value| collect_errors.call(value) }
      else
        []
      end
    end
    errors = collect_errors.call(result.fetch('errors', [])).uniq
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
if ENV['STORE_MODE'] == 'diagnose'
  bundles = all('/v1/bundleIds?' + URI.encode_www_form('filter[identifier]' => 'com.zhangyangbin.idvault', 'limit' => '200'))
  bundles.each do |bundle|
    a = bundle.fetch('attributes')
    puts "Bundle identifier=#{a['identifier']}; seed_prefix_matches_expected=#{a['seedId'] == 'V59XFX9635'}"
    capabilities = all("/v1/bundleIds/#{bundle['id']}/bundleIdCapabilities")
    puts "Enabled bundle capabilities: #{capabilities.map { |c| c.dig('attributes','capabilityType') }.sort.join(', ')}"
  end
  begin
    users = all('/v1/users?' + URI.encode_www_form('fields[users]' => 'roles', 'limit' => '200'))
    roles = users.flat_map { |u| u.dig('attributes','roles') || [] }.tally
    puts "Role counts (no names, emails or user IDs): #{roles}"
  rescue => e
    puts "Role inspection unavailable: #{e.message}"
  end
  puts 'Read-only diagnosis complete; no account or product settings changed.'
  exit
end
if ENV['STORE_MODE'] == 'complete'
  version = all("/v1/apps/#{app_id}/appStoreVersions").find { |v| v.dig('attributes','versionString') == '1.0' && v.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
  raise 'Editable 1.0 required' unless version
  info = all("/v1/apps/#{app_id}/appInfos").find { |r| r.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
  raise 'Editable app information required' unless info
  categories = all('/v1/appCategories')
  utilities = categories.find { |r| r['id'] == 'UTILITIES' }
  raise 'Utilities category not found' unless utilities
  unless info.dig('relationships','primaryCategory','data')
    api('patch', "/v1/appInfos/#{info['id']}", {data: {type: 'appInfos', id: info['id'], relationships: {primaryCategory: link('appCategories', utilities['id'])}}})
    puts 'Primary category set to Utilities.'
  end
  if app.dig('attributes','contentRightsDeclaration').nil?
    api('patch', "/v1/apps/#{app_id}", {data: {type: 'apps', id: app_id, attributes: {contentRightsDeclaration: 'DOES_NOT_USE_THIRD_PARTY_CONTENT'}}})
    puts 'Content rights set for app with no publisher-supplied third-party content.'
  end
  rating = api('get', "/v1/appInfos/#{info['id']}/ageRatingDeclaration").fetch('data')
  booleans = %w[advertising gambling healthOrWellnessTopics lootBox messagingAndChat parentalControls ageAssurance socialMedia socialMediaAgeRestricted unrestrictedWebAccess userGeneratedContent]
  frequencies = %w[alcoholTobaccoOrDrugUseOrReferences contests gamblingSimulated gunsOrOtherWeapons medicalOrTreatmentInformation profanityOrCrudeHumor sexualContentGraphicAndNudity sexualContentOrNudity horrorOrFearThemes matureOrSuggestiveThemes violenceCartoonOrFantasy violenceRealisticProlongedGraphicOrSadistic violenceRealistic]
  attrs = booleans.to_h { |f| [f, false] }.merge(frequencies.to_h { |f| [f, 'NONE'] }).select { |k, _| rating.dig('attributes',k).nil? }
  api('patch', "/v1/ageRatingDeclarations/#{rating['id']}", {data: {type: 'ageRatingDeclarations', id: rating['id'], attributes: attrs}}) unless attrs.empty?
  puts 'Missing age-rating answers saved for offline private file organizer: no ads, social features, public UGC or app-provided medical advice.'
  en = all("/v1/appStoreVersions/#{version['id']}/appStoreVersionLocalizations").find { |r| r.dig('attributes','locale') == 'en-US' }
  attrs = {description: "PageKeep (Shiye) keeps important family documents organized on your device. The current app interface is in Chinese.\n\nImport photos, recognize text on device, verify editable fields, and store originals and confirmed fields encrypted locally. Tap recognized text to create or fill fields. Organize documents by family member, search confirmed fields, set local expiry reminders, export PDF packets and create password-encrypted backups. No PageKeep account is required. Documents and OCR content are not sent to remote recognition services or the developer.\n\nFree: one member and up to 10 documents in the entire vault; a document may contain multiple pages. The optional Pro non-consumable purchase unlocks multiple members and unlimited documents, subject to device storage and per-backup limits. Pay once, no recurring subscription. Restore Purchases is available. Existing documents remain accessible when purchase status changes.\n\nOCR can make mistakes; verify against originals. This app does not authenticate documents or provide medical advice. Before uninstalling or changing devices, export a backup and keep its password safe. There is no developer-hosted copy of your files.", keywords: 'documents,vault,private,offline,family,passport,certificate,OCR,encrypted,backup,expiry,PDF', supportUrl: 'https://nikefd.github.io/nexttime-site/shiye/support.html'}
  if en
    missing = attrs.select { |k,_| en.dig('attributes',k.to_s).to_s.empty? }
    api('patch', "/v1/appStoreVersionLocalizations/#{en['id']}", {data: {type: 'appStoreVersionLocalizations', id: en['id'], attributes: missing}}) unless missing.empty?
  else
    api('post', '/v1/appStoreVersionLocalizations', {data: {type: 'appStoreVersionLocalizations', attributes: attrs.merge(locale: 'en-US'), relationships: {appStoreVersion: link('appStoreVersions', version['id'])}}})
  end
  puts 'English store description, keywords and support URL completed, with Chinese-interface disclosure.'
  review = api('get', "/v1/appStoreVersions/#{version['id']}/appStoreReviewDetail").fetch('data')
  fields = %w[contactFirstName contactLastName contactPhone contactEmail]
  if fields.any? { |f| review.dig('attributes',f).to_s.empty? }
    previous_app = all('/v1/apps?' + URI.encode_www_form('filter[bundleId]' => 'com.zhangyangbin.NextTime')).first
    source = nil
    if previous_app
      all("/v1/apps/#{previous_app['id']}/appStoreVersions?limit=200").each do |v|
        contact = api('get', "/v1/appStoreVersions/#{v['id']}/appStoreReviewDetail", allow_missing: true)&.dig('data','attributes')
        if contact && fields.all? { |f| !contact[f].to_s.empty? }
          source = contact
          break
        end
      end
    end
    if source
      missing = fields.select { |f| review.dig('attributes',f).to_s.empty? }.to_h { |f| [f, source[f]] }
      api('patch', "/v1/appStoreReviewDetails/#{review['id']}", {data: {type: 'appStoreReviewDetails', id: review['id'], attributes: missing}})
      puts 'Reused same developer existing NextTime review contact; no personal contact values logged.'
    else
      puts 'No complete existing developer review contact found; user must complete contact details.'
    end
  end
  point = all("/v1/apps/#{app_id}/appPricePoints?" + URI.encode_www_form('filter[territory]' => 'CHN', 'limit' => '200')).find { |r| BigDecimal(r.dig('attributes','customerPrice')) == BigDecimal('0') }
  raise 'Free App price point missing' unless point
  api('post', '/v1/appPriceSchedules', {data: {type: 'appPriceSchedules', relationships: {app: link('apps', app_id), baseTerritory: link('territories', 'CHN'), manualPrices: {data: [{type: 'appPrices', id: '${free-price}'}]}}}, included: [{type: 'appPrices', id: '${free-price}', attributes: {startDate: nil, endDate: nil}, relationships: {appPricePoint: link('appPricePoints', point['id'])}}]})
  puts 'App download price set to free; lifetime Pro price not changed.'
  puts 'Completed editable required metadata. No review submitted in this mode.'
  exit
end
require 'digest'
def upload_asset(resource, file)
  bytes = File.binread(file)
  resource.dig('attributes','uploadOperations').each do |op|
    uri = URI(op.fetch('url'))
    raise 'Insecure upload URL' unless uri.scheme == 'https'
    req = Net::HTTPGenericRequest.new(op.fetch('method'), true, true, uri)
    op.fetch('requestHeaders', []).each { |h| req[h.fetch('name')] = h.fetch('value') }
    req.body = bytes.byteslice(op.fetch('offset'), op.fetch('length'))
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 60) { |h| h.request(req) }
    raise "Asset upload HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
  end
  api('patch', "/v1/#{resource['type']}/#{resource['id']}", {data: {type: resource['type'], id: resource['id'], attributes: {uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes)}}})
end

if ENV['STORE_MODE'] == 'review_evidence'
  version = all("/v1/apps/#{app_id}/appStoreVersions").find { |r| r.dig('attributes', 'versionString') == '1.0' }
  raise 'Version 1.0 missing' unless version
  version_id = version.fetch('id')
  build = api('get', "/v1/appStoreVersions/#{version_id}/build").fetch('data')
  raise 'Expected build 28' unless build.dig('attributes', 'version') == '28'
  detail = api('get', "/v1/appStoreVersions/#{version_id}/appStoreReviewDetail").fetch('data')
  detail_id = detail.fetch('id')
  notes = File.read('idvault-source/review-evidence/notes.txt')
  raise 'Review notes missing evidence' unless notes.include?('PageKeep-Review-Demo.mp4')
  files = Dir.glob('idvault-source/review-evidence/*.mp4').sort
  raise 'Expected combined physical-device recording' unless files.length == 1
  existing = all("/v1/appStoreReviewDetails/#{detail_id}/appStoreReviewAttachments")
  previous = existing.find { |item| item.dig('attributes', 'fileName') == '01-Document-Workflow.mp4' }
  api('delete', "/v1/appStoreReviewAttachments/#{previous['id']}") if previous
  files.each do |file|
    name = File.basename(file)
    upload = existing.find { |item| item.dig('attributes', 'fileName') == name }
    unless upload
      upload = api('post', '/v1/appStoreReviewAttachments', {data: {type: 'appStoreReviewAttachments', attributes: {fileName: name, fileSize: File.size(file)}, relationships: {appStoreReviewDetail: link('appStoreReviewDetails', detail_id)}}}).fetch('data')
      upload_asset(upload, file)
    end
    state = nil
    12.times do
      state = api('get', "/v1/appStoreReviewAttachments/#{upload['id']}").dig('data', 'attributes', 'assetDeliveryState', 'state')
      break if %w[COMPLETE FAILED].include?(state)
      sleep 5
    end
    puts "Review attachment #{name}: #{state}"
    raise 'Video attachment not ready' unless state == 'COMPLETE'
  end
  api('patch', "/v1/appStoreReviewDetails/#{detail_id}", {data: {type: 'appStoreReviewDetails', id: detail_id, attributes: {notes: notes}}})
  puts 'Updated App Review Information notes.'
  submissions = all('/v1/reviewSubmissions?' + URI.encode_www_form('filter[app]' => app_id, 'filter[platform]' => 'IOS'))
  submissions.each do |submission|
    items = all("/v1/reviewSubmissions/#{submission['id']}/items?include=appStoreVersion,inAppPurchaseVersion")
    next unless items.any? { |item| item.dig('relationships','appStoreVersion','data','id') == version_id }
    puts "Existing submission #{submission['id']}: #{submission.dig('attributes','state')}"
    items.each { |item| puts "Review item #{item['id']}: #{item.dig('attributes','state')}; app=#{!!item.dig('relationships','appStoreVersion','data')}; purchase=#{!!item.dig('relationships','inAppPurchaseVersion','data')}" }
    state = submission.dig('attributes','state')
    next unless %w[UNRESOLVED_ISSUES READY_FOR_REVIEW].include?(state)
    raise 'Expected app and Pro purchase together' unless items.any? { |i| i.dig('relationships','inAppPurchaseVersion','data') }
    items.select { |i| i.dig('attributes','state') == 'REJECTED' }.each do |item|
      api('patch', "/v1/reviewSubmissionItems/#{item['id']}", {data: {type: 'reviewSubmissionItems', id: item['id'], attributes: {resolved: true}}})
    end
    result = api('patch', "/v1/reviewSubmissions/#{submission['id']}", {data: {type: 'reviewSubmissions', id: submission['id'], attributes: {submitted: true}}})
    puts "Resubmission state: #{result.dig('data','attributes','state')}"
    puts "App state after resubmission: #{api('get', "/v1/appStoreVersions/#{version_id}").dig('data','attributes','appStoreState')}"
    exit
  end
  exit
end

if ENV['STORE_MODE'] == 'submit'
  version = all("/v1/apps/#{app_id}/appStoreVersions").find { |v| v.dig('attributes','versionString') == '1.0' }
  raise 'App version 1.0 missing' unless version
  puts "App state before submission: #{version.dig('attributes','appStoreState')}"
  if %w[WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE READY_FOR_SALE].include?(version.dig('attributes','appStoreState'))
    puts 'Version already submitted or approved; no duplicate submission.'
    exit
  end
  raise 'Editable 1.0 required' unless version.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION'
  product = all("/v1/apps/#{app_id}/inAppPurchasesV2").find { |r| r.dig('attributes','productId') == PRODUCT_ID }
  raise 'Approved lifetime product missing' unless product
  purchase_versions = all("/v2/inAppPurchases/#{product['id']}/versions")
  purchase_version = purchase_versions.find { |v| %w[PREPARE_FOR_SUBMISSION READY_TO_SUBMIT READY_FOR_REVIEW].include?(v.dig('attributes','state')) }
  raise 'Editable lifetime purchase version missing' unless purchase_version
  submissions = all('/v1/reviewSubmissions?' + URI.encode_www_form('filter[app]' => app_id, 'filter[platform]' => 'IOS'))
  submission = submissions.find { |r| r.dig('attributes','state') == 'READY_FOR_REVIEW' } || api('post', '/v1/reviewSubmissions', {data: {type: 'reviewSubmissions', attributes: {platform: 'IOS'}, relationships: {app: link('apps', app_id)}}}).fetch('data')
  items = all("/v1/reviewSubmissions/#{submission['id']}/items?include=appStoreVersion,inAppPurchaseVersion")
  {'inAppPurchaseVersion' => ['inAppPurchaseVersions', purchase_version['id']], 'appStoreVersion' => ['appStoreVersions', version['id']]}.each do |relationship, (type, id)|
    next if items.any? { |r| r.dig('relationships', relationship, 'data', 'id') == id }
    api('post', '/v1/reviewSubmissionItems', {data: {type: 'reviewSubmissionItems', relationships: {reviewSubmission: link('reviewSubmissions', submission['id']), relationship => link(type, id)}}})
    puts "Added #{relationship} to review submission."
  end
  result = api('patch', "/v1/reviewSubmissions/#{submission['id']}", {data: {type: 'reviewSubmissions', id: submission['id'], attributes: {submitted: true}}})
  puts "Review submission state: #{result.dig('data','attributes','state')}"
  current = api('get', "/v1/appStoreVersions/#{version['id']}")
  puts "App state after submission: #{current.dig('data','attributes','appStoreState')}"
  exit
end
if ENV['STORE_MODE'] == 'screenshots'
  version = all("/v1/apps/#{app_id}/appStoreVersions").find { |v| v.dig('attributes','versionString') == '1.0' && v.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
  raise 'Editable version required' unless version
  locale = all("/v1/appStoreVersions/#{version['id']}/appStoreVersionLocalizations").find { |l| l.dig('attributes','locale') == 'zh-Hans' }
  sets = all("/v1/appStoreVersionLocalizations/#{locale['id']}/appScreenshotSets")
  {'iphone' => 'APP_IPHONE_67', 'ipad' => 'APP_IPAD_PRO_3GEN_129'}.each do |dir, display|
    files = Dir.glob("idvault-source/docs/store/screenshots/#{dir}/*.png").sort
    raise "Missing #{dir} screenshots" if files.empty?
    set = sets.find { |r| r.dig('attributes','screenshotDisplayType') == display } || api('post', '/v1/appScreenshotSets', {data: {type: 'appScreenshotSets', attributes: {screenshotDisplayType: display}, relationships: {appStoreVersionLocalization: link('appStoreVersionLocalizations', locale['id'])}}}).fetch('data')
    existing = all("/v1/appScreenshotSets/#{set['id']}/appScreenshots")
    files.each do |file|
      old = existing.find { |r| r.dig('attributes','fileName') == File.basename(file) }
      if old
        puts "Existing #{dir}/#{File.basename(file)}: #{old.dig('attributes','assetDeliveryState','state')}"
        next
      end
      resource = api('post', '/v1/appScreenshots', {data: {type: 'appScreenshots', attributes: {fileName: File.basename(file), fileSize: File.size(file)}, relationships: {appScreenshotSet: link('appScreenshotSets', set['id'])}}}).fetch('data')
      upload_asset(resource, file)
      puts "Uploaded #{dir}/#{File.basename(file)}"
    end
  end
  product = all("/v1/apps/#{app_id}/inAppPurchasesV2").find { |r| r.dig('attributes','productId') == PRODUCT_ID }
  raise 'Lifetime product missing' unless product
  review_shot = api('get', "/v2/inAppPurchases/#{product['id']}/appStoreReviewScreenshot", allow_missing: true)&.dig('data')
  if review_shot.nil?
    file = 'idvault-source/docs/store/screenshots/iphone/02-family.png'
    resource = api('post', '/v1/inAppPurchaseAppStoreReviewScreenshots', {data: {type: 'inAppPurchaseAppStoreReviewScreenshots', attributes: {fileName: 'pro-multiple-members.png', fileSize: File.size(file)}, relationships: {inAppPurchaseV2: link('inAppPurchases', product['id'])}}}).fetch('data')
    upload_asset(resource, file)
    puts 'Uploaded IAP review screenshot showing Pro multiple-member management with fictional data.'
  else
    puts "IAP review screenshot state: #{review_shot.dig('attributes','assetDeliveryState','state')}"
  end
  api('patch', "/v2/inAppPurchases/#{product['id']}", {data: {type: 'inAppPurchases', id: product['id'], attributes: {reviewNote: 'One-time non-consumable Pro purchase unlocks multiple family members and unlimited documents. Free tier: 1 member and 10 documents total. Screenshot shows the multiple-member management feature in Pro using fictional sample data. Open the Pro screen on Home for purchase and Restore Purchases. No app account or server login is required; personal document data stays on device.'}}})
  puts 'Screenshots uploaded to editable version only; no review submitted.'
  exit
end
if ENV['STORE_MODE'] == 'releaseprep'
  version = all("/v1/apps/#{app_id}/appStoreVersions?" + URI.encode_www_form('filter[platform]' => 'IOS')).find { |v| v.dig('attributes','versionString') == '1.0' && v.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
  raise 'Editable 1.0 required' unless version
  build = all('/v1/builds?' + URI.encode_www_form('filter[app]' => app_id, 'filter[version]' => '28')).find { |b| b.dig('attributes','processingState') == 'VALID' }
  raise 'Valid build 28 required' unless build
  api('patch', "/v1/appStoreVersions/#{version['id']}", {data: {type: 'appStoreVersions', id: version['id'], attributes: {releaseType: 'AFTER_APPROVAL', copyright: '2026 Yangbin Zhang'}, relationships: {build: link('builds', build['id'])}}})
  infos = all("/v1/apps/#{app_id}/appInfos")
  infos.each do |info|
    next unless info.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION'
    all("/v1/appInfos/#{info['id']}/appInfoLocalizations").each do |l|
      api('patch', "/v1/appInfoLocalizations/#{l['id']}", {data: {type: 'appInfoLocalizations', id: l['id'], attributes: {privacyPolicyUrl: 'https://nikefd.github.io/nexttime-site/shiye/privacy.html'}}})
    end
  end
  detail = api('get', "/v1/appStoreVersions/#{version['id']}/appStoreReviewDetail", allow_missing: true)&.dig('data')
  attrs = {demoAccountRequired: false, notes: 'Shiye is an offline document organizer. No registration or demo account is required. Free: 1 member and 10 documents; multiple pages count as one document. Non-consumable Pro purchase unlocks multiple members and unlimited documents; Restore Purchases is available on the Pro screen. OCR and document contents remain on device. To test: add a photo from the system picker, verify editable fields, then save. Purchases use Apple StoreKit.'}
  if detail
    api('patch', "/v1/appStoreReviewDetails/#{detail['id']}", {data: {type: 'appStoreReviewDetails', id: detail['id'], attributes: attrs}})
  else
    api('post', '/v1/appStoreReviewDetails', {data: {type: 'appStoreReviewDetails', attributes: attrs, relationships: {appStoreVersion: link('appStoreVersions', version['id'])}}})
  end
  puts 'Selected build 28, after-approval release, privacy URL and offline review instructions saved. Contact details still require completion; no review submitted.'
  exit
end
if ENV['STORE_MODE'] == 'listing'
  copy = JSON.parse(File.read(File.join(__dir__, 'idvault_listing_zh.json')))
  versions = all("/v1/apps/#{app_id}/appStoreVersions?" + URI.encode_www_form('filter[platform]' => 'IOS', 'limit' => '200'))
  version = versions.find { |v| v.dig('attributes', 'versionString') == '1.0' && v.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
  raise 'Editable app version 1.0 is required' unless version
  locales = all("/v1/appStoreVersions/#{version['id']}/appStoreVersionLocalizations?limit=200")
  locale = locales.find { |l| l.dig('attributes','locale') == 'zh-Hans' }
  raise 'Existing zh-Hans version locale is required' unless locale
  api('patch', "/v1/appStoreVersionLocalizations/#{locale['id']}", { data: { type: 'appStoreVersionLocalizations', id: locale['id'], attributes: { description: copy.fetch('description'), keywords: copy.fetch('keywords'), supportUrl: 'https://nikefd.github.io/nexttime-site/shiye/support.html' } } })
  infos = all("/v1/apps/#{app_id}/appInfos?limit=200")
  infos.each do |info|
    next unless %w[PREPARE_FOR_SUBMISSION READY_FOR_SALE].include?(info.dig('attributes','appStoreState'))
    localizations = all("/v1/appInfos/#{info['id']}/appInfoLocalizations?limit=200")
    chinese = localizations.find { |l| l.dig('attributes','locale') == 'zh-Hans' }
    next unless chinese
    api('patch', "/v1/appInfoLocalizations/#{chinese['id']}", { data: { type: 'appInfoLocalizations', id: chinese['id'], attributes: { name: '拾页 · 本地证件夹', subtitle: copy.fetch('subtitle'), privacyPolicyUrl: 'https://nikefd.github.io/nexttime-site/shiye/privacy.html' } } })
    break
  end
  info = infos.find { |i| i.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
  raise 'Editable app info required' unless info
  english = all("/v1/appInfos/#{info['id']}/appInfoLocalizations").find { |l| l.dig('attributes','locale') == 'en-US' }
  attrs = {name: 'PageKeep: Document Vault', subtitle: 'Private document organizer', privacyPolicyUrl: 'https://nikefd.github.io/nexttime-site/shiye/privacy.html'}
  if english
    api('patch', "/v1/appInfoLocalizations/#{english['id']}", {data: {type: 'appInfoLocalizations', id: english['id'], attributes: attrs}})
  else
    api('post', '/v1/appInfoLocalizations', {data: {type: 'appInfoLocalizations', attributes: attrs.merge(locale: 'en-US'), relationships: {appInfo: link('appInfos', info['id'])}}})
  end
  puts 'Approved Chinese name and English name PageKeep: Document Vault saved.'
  puts 'Chinese description, keywords and subtitle prepared in the editable app record.'
  puts 'Shiye Chinese name and published support/privacy URLs configured; no review submission triggered.'
  exit
end
products = all("/v1/apps/#{app_id}/inAppPurchasesV2?limit=200")
product = products.find { |p| p.dig('attributes', 'productId') == PRODUCT_ID }
if !product && APPLY
  product = api('post', '/v2/inAppPurchases', { data: { type: 'inAppPurchases', attributes: {
    name: 'IDVault Pro Lifetime', productId: PRODUCT_ID, inAppPurchaseType: 'NON_CONSUMABLE'
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
      'en-US' => ['Shiye Pro', 'Unlock multiple members and unlimited documents.'] }.each do |locale, (name, description)|
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
  review = api('get', "/v1/appStoreVersions/#{v['id']}/appStoreReviewDetail", allow_missing: true)
  a = review&.dig('data','attributes') || {}
  puts "Review detail presence: #{%w[contactFirstName contactLastName contactPhone contactEmail notes].to_h { |f| [f, !a[f].to_s.empty?] }}"
  build = api('get', "/v1/appStoreVersions/#{v['id']}/build", allow_missing: true)
  puts "Selected build: #{build&.dig('data','attributes','version') || 'none'}"
  locales = all("/v1/appStoreVersions/#{v['id']}/appStoreVersionLocalizations?limit=200")
  locales.each do |l|
    a = l.fetch('attributes')
    presence = %w[description keywords supportUrl].to_h { |f| [f, !a[f].to_s.empty?] }
    screenshots = all("/v1/appStoreVersionLocalizations/#{l['id']}/appScreenshotSets?limit=200")
    puts "Store listing #{a['locale']}: #{presence}; screenshot_sets=#{screenshots.size}"
    screenshots.each do |set|
      assets = all("/v1/appScreenshotSets/#{set['id']}/appScreenshots")
      puts "Screenshot assets #{set.dig('attributes','screenshotDisplayType')}: #{assets.map { |r| [r.dig('attributes','fileName'), r.dig('attributes','assetDeliveryState','state')] }.to_h}"
    end
  end
end
all("/v1/apps/#{app_id}/appInfos?limit=200").each do |info|
  all("/v1/appInfos/#{info['id']}/appInfoLocalizations?limit=200").each do |locale|
    a = locale.fetch('attributes')
    puts "App info #{a['locale']}: name=#{a['name']}; subtitle_present=#{!a['subtitle'].to_s.empty?}; privacy_url_present=#{!a['privacyPolicyUrl'].to_s.empty?}"
  end
end
puts 'No review submission or automatic release was triggered.'
