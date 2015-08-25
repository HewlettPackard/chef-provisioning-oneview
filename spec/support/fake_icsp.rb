require 'sinatra/base'
require 'json'

class FakeIcsp < Sinatra::Base

  get '/rest/version' do
    json_response(200, 'version.json', '102')
  end

  get '/rest/index/resources' do
    version = env['HTTP_X_API_VERSION']
    category = params['category']
    return json_response(404, 'error_404.json', version) if category.nil?
    if category == 'osdserver' && params['query'].match(/osdServerSerialNumber:"VCGE9KB041"/)
      return json_response(200, 'server_by_sn_VCGE9KB041.json', version)
    elsif category == 'osdserver' && params['query'].match(/osdServerSerialNumber:"FAKESN"/)
      return json_response(200, 'server_by_sn_empty.json', version)
    else
      return json_response(404, 'error_404.json', version)
    end
  end

  get '/rest/os-deployment-servers' do
    version = env['HTTP_X_API_VERSION']
    json_response(200, 'os-deployment-servers.json', version)
  end

  post '/rest/login-sessions' do
    version = env['HTTP_X_API_VERSION']
    json_response(200, 'login.json', version)
  end

  get '/' do
    { message: 'Fake ICsp works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  post '/' do
    { message: 'Fake ICsp works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  put '/' do
    { message: 'Fake ICsp works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  delete '/' do
    { message: 'Fake ICsp works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  get '/*' do # All other paths should return a 404 error
    json_response(404, 'error_404.json', '102')
  end

  private

  def json_response(response_code, file_name, version = 102)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + "/fixtures/icsp/v#{version}/" + file_name, 'rb').read
  end
end
