require 'sinatra/base'
require 'json'

class FakeOneView < Sinatra::Base

  get '/rest/version' do
    json_response(200, 'version.json', '120')
  end

  post '/rest/login-sessions' do
    version = env['HTTP_X_API_VERSION']
    json_response(200, 'login.json', version)
  end

  get '/rest/server-profile-templates' do
    version = env['HTTP_X_API_VERSION']
    file_name = 'server-profile-templates_invalid.json'
    if params['filter'] && params['filter'].match('name matches')
      if params['filter'].match('Web Server Template')
        file_name = 'server-profile-templates_WebServerTemplate.json'
      end
    end
    json_response(200, file_name, version)
  end

  get '/rest/server-profile-templates/:id/new-profile' do |id|
    version = env['HTTP_X_API_VERSION']
    if id == 'd64da635-f08a-41d4-b6eb-6517206a8bae'
      json_response(200, 'server-profile-templates_new-profile_WebServerTemplate.json', version)
    else
      json_response(404, 'error_404.json', '120')
    end
  end

  get '/rest/server-profiles' do
    version = env['HTTP_X_API_VERSION']
    file_name = 'server-profiles.json'
    if params['filter']
      if params['filter'].match('matches \'\'') || params['filter'].match('INVALIDFILTER')
        file_name = 'server-profiles_invalid_filter.json'
      elsif params['filter'].match('serialNumber matches')
        if params['filter'].match('VCGE9KB041')
          file_name = 'server-profiles_sn_VCGE9KB041.json'
        else
          file_name = 'server-profiles_sn_empty.json'
        end
      elsif params['filter'].match('name matches')
        if params['filter'].match('Template - Web Server')
          file_name = 'server-profiles_name_Template-WebServer.json'
        elsif params['filter'].match('chef-web01')
          file_name = 'server-profiles_name_chef-web01.json'
        elsif $server_created == 'chef-web03'
          file_name = 'server-profiles_name_chef-web03.json'
        else
          file_name = 'server-profiles_name_empty.json'
        end
      end
    end
    json_response(200, file_name, version)
  end

  post '/rest/server-profiles' do
    body = JSON.parse(request.body.read.to_s)
    $server_created = body['name']
    { 'uri' => '/rest/tasks/FAKETASK' }.to_json
  end

  delete '/rest/server-profiles/:id' do |_id|
    { 'uri' => '/rest/tasks/FAKETASK' }.to_json
  end

  get '/rest/server-hardware' do
    version = env['HTTP_X_API_VERSION']
    file_name = 'server-hardware.json'
    if params['filter'].match('enclosure-groups/3a11ccdd-b352-4046-a568-a8b0faa6cc39') # && params['filter'].match('') # TODO
      file_name = 'server-hardware_Template-WebServer.json'
    end
    json_response(200, file_name, version)
  end

  get '/rest/server-hardware/:id' do |id|
    version = env['HTTP_X_API_VERSION']
    if id == '31363636-3136-584D-5132-333230314D38' || id == '37333036-3831-584D-5131-303030323037'
      json_response(200, 'server-hardware_specific.json', version)
    else
      json_response(404, 'error_404.json', '120')
    end
  end

  put '/rest/server-hardware/:id/powerState' do |_id|
    { 'uri' => '/rest/tasks/FAKETASK' }.to_json
  end

  get '/rest/tasks/FAKETASK' do
    version = env['HTTP_X_API_VERSION']
    json_response(200, 'tasks_fake_complete.json', version)
  end

  get '/' do
    { message: 'Fake OneView works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  post '/' do
    { message: 'Fake OneView works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  put '/' do
    { message: 'Fake OneView works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  delete '/' do
    { message: 'Fake OneView works!', method: env['REQUEST_METHOD'], content_type: env['CONTENT_TYPE'], query: env['QUERY_STRING'],
      api_version: env['HTTP_X_API_VERSION'], auth: env['HTTP_AUTH'], params: params }.to_json
  end

  get '/*' do # All other paths should return a 404 error
    json_response(404, 'error_404.json', '120')
  end

  private

  def json_response(response_code, file_name, version = 120)
    content_type :json
    status response_code
    File.open(File.dirname(__FILE__) + "/fixtures/oneview/v#{version}/" + file_name, 'rb').read
  end
end
