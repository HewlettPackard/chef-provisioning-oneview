module RestAPI
  # API calls for OneView and ICsp
  def rest_api(host, type, path, options = {})
    disable_ssl = false
    case host
    when 'icsp', :icsp
      uri = URI.parse(URI.escape(@icsp_base_url + path))
      options['X-API-Version'] ||= @icsp_api_version unless [:put, 'put'].include?(type.downcase)
      options['auth'] ||= @icsp_key
      disable_ssl = true if @icsp_disable_ssl
    when 'oneview', :oneview
      uri = URI.parse(URI.escape(@oneview_base_url + path))
      options['X-API-Version'] ||= @oneview_api_version
      options['auth'] ||= @oneview_key
      disable_ssl = true if @oneview_disable_ssl
    else
      raise "Invalid rest host: #{host}"
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if disable_ssl

    case type.downcase
    when 'get', :get
      request = Net::HTTP::Get.new(uri.request_uri)
    when 'post', :post
      request = Net::HTTP::Post.new(uri.request_uri)
    when 'put', :put
      request = Net::HTTP::Put.new(uri.request_uri)
    when 'delete', :delete
      request = Net::HTTP::Delete.new(uri.request_uri)
    else
      raise "Invalid rest call: #{type}"
    end
    options['Content-Type'] ||= 'application/json'
    options.delete('Content-Type')  if [:none, 'none', nil].include?(options['Content-Type'])
    options.delete('X-API-Version') if [:none, 'none', nil].include?(options['X-API-Version'])
    options.delete('auth')          if [:none, 'none', nil].include?(options['auth'])
    options.each do |key, val|
      if key.casecmp('body') == 0
        request.body = val.to_json rescue val
      else
        request[key] = val
      end
    end

    response = http.request(request)
    JSON.parse(response.body) rescue response
  end
end # End module
