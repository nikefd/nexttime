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

app_id = '6757946762'
version_id = ENV.fetch('ASC_VERSION_ID')
build_number = ENV.fetch('ASC_BUILD_NUMBER')
version = api('get', "/v1/appStoreVersions/#{version_id}?include=app,build")
data = version.fetch('data')
raise 'Unexpected app or release configuration' unless data.dig('relationships', 'app', 'data', 'id') == app_id &&
  data.dig('attributes', 'versionString') == ENV.fetch('APP_VERSION') &&
  data.dig('attributes', 'releaseType') == 'AFTER_APPROVAL'
build_id = data.dig('relationships', 'build', 'data', 'id')
build = version.fetch('included', []).find { |item| item['type'] == 'builds' && item['id'] == build_id }
raise 'Unexpected or unprocessed build' unless build && build.dig('attributes', 'version') == build_number &&
  build.dig('attributes', 'processingState') == 'VALID'

state = data.dig('attributes', 'appStoreState')
puts "Version #{ENV.fetch('APP_VERSION')} (#{build_number}): #{state}"
exit if %w[WAITING_FOR_REVIEW IN_REVIEW PENDING_DEVELOPER_RELEASE READY_FOR_SALE READY_FOR_DISTRIBUTION].include?(state)
raise 'Version not editable for submission' unless state == 'PREPARE_FOR_SUBMISSION'

infos = all("/v1/apps/#{app_id}/appInfos")
info = infos.find { |item| item.dig('attributes', 'appStoreState') == 'PREPARE_FOR_SUBMISSION' } ||
       infos.find { |item| item.dig('attributes', 'state') == 'PREPARE_FOR_SUBMISSION' }
raise 'Editable app information not found' unless info
rating = api('get', "/v1/appInfos/#{info.fetch('id')}/ageRatingDeclaration").fetch('data')
answers = {
  socialMedia: false, socialMediaAgeRestricted: false, userGeneratedContent: false,
  messagingAndChat: false, advertising: false, gambling: false, lootBox: false,
  parentalControls: false, ageAssurance: false, healthOrWellnessTopics: true
}.select { |field, _| rating.dig('attributes', field.to_s).nil? }
unless answers.empty?
  api('patch', "/v1/ageRatingDeclarations/#{rating.fetch('id')}",
      {data: {type: 'ageRatingDeclarations', id: rating.fetch('id'), attributes: answers}})
  puts "Completed missing age-rating fields: #{answers.keys.join(', ')}"
end

submissions = all('/v1/reviewSubmissions?' + URI.encode_www_form('filter[app]' => app_id, 'filter[platform]' => 'IOS'))
drafts = submissions.select { |item| item.dig('attributes', 'state') == 'READY_FOR_REVIEW' }
draft = drafts.find do |candidate|
  items = all("/v1/reviewSubmissions/#{candidate.fetch('id')}/items?include=appStoreVersion")
  items.empty? || items.all? { |item| item.dig('relationships', 'appStoreVersion', 'data', 'id') == version_id }
end
draft ||= api('post', '/v1/reviewSubmissions',
              {data: {type: 'reviewSubmissions', attributes: {platform: 'IOS'}, relationships: {app: link('apps', app_id)}}}).fetch('data')
draft_id = draft.fetch('id')
items = all("/v1/reviewSubmissions/#{draft_id}/items?include=appStoreVersion")
unless items.any? { |item| item.dig('relationships', 'appStoreVersion', 'data', 'id') == version_id }
  api('post', '/v1/reviewSubmissionItems', {data: {type: 'reviewSubmissionItems', relationships: {
    reviewSubmission: link('reviewSubmissions', draft_id), appStoreVersion: link('appStoreVersions', version_id)
  }}})
end
result = api('patch', "/v1/reviewSubmissions/#{draft_id}",
             {data: {type: 'reviewSubmissions', id: draft_id, attributes: {submitted: true}}})
puts "Submitted NextTime for App Review: #{result.dig('data', 'attributes', 'state')}"
