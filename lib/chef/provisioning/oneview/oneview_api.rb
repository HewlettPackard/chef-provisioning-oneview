require_relative 'v1.20/api'
require_relative 'v2.0/api'

module OneViewAPI
  private
  
  include OneViewAPIv1_20
  include OneViewAPIv2_0

  # API calls for OneView and Altair
  def rest_api(host, type, path, options = {})
    disable_ssl = false
    case host
    when 'altair', :altair
      uri = URI.parse(URI.escape(@altair_base_url + path))
      options['X-API-Version'] ||= @altair_api_version unless [:put, 'put'].include?(type.downcase)
      options['auth'] ||= @altair_key
      disable_ssl = true if @altair_disable_ssl
    when 'oneview', :oneview
      uri = URI.parse(URI.escape(@oneview_base_url + path))
      options['X-API-Version'] ||= @oneview_api_version
      options['auth'] ||= @oneview_key
      disable_ssl = true if @oneview_disable_ssl
    else
      raise "Invalid rest host: #{host}"
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
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
    options.delete('Content-Type')  if [:none, "none", nil].include?(options['Content-Type'])
    options.delete('X-API-Version') if [:none, "none", nil].include?(options['X-API-Version'])
    options.delete('auth')          if [:none, "none", nil].include?(options['auth'])
    options.each do |key, val|
      if key.downcase == 'body'
        request.body = val.to_json rescue val
      else
        request[key] = val
      end
    end

    response = http.request(request)
    JSON.parse( response.body ) rescue response
  end
  
  def get_oneview_api_version
    begin
      version = rest_api(:oneview, :get, "/rest/version", { 'Content-Type'=>:none, "X-API-Version"=>:none, "auth"=>:none })['currentVersion']
      raise "Couldn't get API version" unless version
      if version.class != Fixnum
        version = version.to_i
        raise "API version type mismatch" if !version > 0
      end
    rescue
      puts "Failed to get OneView API version. Setting to default (120)"
      version = 120
    end
    version
  end
  
  def get_altair_api_version
    begin
      version = rest_api(:altair, :get, "/rest/version", { 'Content-Type'=>:none, "X-API-Version"=>:none, "auth"=>:none })['currentVersion']
      raise "Couldn't get API version" unless version
      if version.class != Fixnum
        version = version.to_i
        raise "API version type mismatch" if !version > 0
      end
    rescue
      puts "Failed to get Altair API version. Setting to default (102)"
      version = 102
    end
    version
  end

  # Login functions
  def auth_tokens
    @altair_key  ||= login_to_altair
    @oneview_key ||= login_to_oneview
    {'altair_key' => @altair_key, 'oneview_key'=> @oneview_key}
  end

  def login_to_altair
    path = "/rest/login-sessions"
    options = {
      'body' => {
        'userName' => @altair_username,
        'password' => @altair_password,
        'authLoginDomain' => 'LOCAL'
      }
    }
    response = rest_api(:altair, :post, path, options)
    return response['sessionID'] if response['sessionID']
    raise("\nERROR! Couldn't log into OneView server at #{@oneview_base_url}. Response:\n#{response}")
  end

  def login_to_oneview
    path = "/rest/login-sessions"
    options = {
      'body' => {
        'userName' => @oneview_username,
        'password' => @oneview_password,
        'authLoginDomain' => 'LOCAL'
      }
    }
    response = rest_api(:oneview, :post, path, options)
    return response['sessionID'] if response['sessionID']
    raise("\nERROR! Couldn't log into OneView server at #{@oneview_base_url}. Response:\n#{response}")
  end


  def get_oneview_profile_by_sn(serialNumber)
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=serialNumber matches '#{serialNumber}'&sort=name:asc")
    return matching_profiles['members'].first if matching_profiles['count'] > 0
    nil
  end

  def get_altair_server_by_sn(serialNumber)
    search_result = rest_api(:altair, :get,
        "/rest/index/resources?category=osdserver&query='osdServerSerialNumber:\"#{serial_number}\"'")['members'] rescue nil
    if search_result && search_result.size == 1 && search_result.first['attributes']['osdServerSerialNumber'] == serial_number
      my_server = search_result.first
    end
    unless my_server && my_server['uri']
      os_deployment_servers = rest_api(:altair, :get, '/rest/os-deployment-servers')
      # Pick the relevant os deployment server from altair
      my_server = nil
      os_deployment_servers['members'].each do |server|
        if server['serialNumber'] == serialNumber
          my_server = server
          break
        end
      end
    end
    my_server
  end


  def power_on(action_handler, machine_spec, machine_options, hardware_uri=nil)
    set_power_state(action_handler, machine_spec, "on", hardware_uri)
  end

  def power_off(action_handler, machine_spec, machine_options, hardware_uri=nil)
    set_power_state(action_handler, machine_spec, "off", hardware_uri)
  end

  def set_power_state(action_handler, machine_spec, state, hardware_uri=nil)
    case state
    when :on, "on", true
      state = "on"
    when :off, "off", false
      state = "off"
    else raise "Invalid power state #{state}"
    end

    if hardware_uri.nil?
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
      hardware_uri = profile['serverHardwareUri']
    end

    hardware_info = rest_api(:oneview, :get, hardware_uri)
    unless hardware_info['powerState'].downcase == state
      action_handler.perform_action "Power #{state} server #{hardware_info['name']} for #{machine_spec.name}" do
        action_handler.report_progress "INFO: Powering #{state} server #{hardware_info['name']} for #{machine_spec.name}"
        task = rest_api(:oneview, :put, "#{hardware_uri}/powerState", {'body'=>{"powerState"=>state.capitalize, "powerControl"=>"MomentaryPress"}})
        task_uri = task['uri']
        60.times do # Wait for up to 10 minutes
          task = rest_api(:oneview, :get, task_uri)
          break if task['taskState'].downcase == "completed"
          print "."
          sleep 10
        end
        raise "Powering #{state} machine #{machine_spec.name} failed!" unless task['taskState'].downcase == "completed"
      end
    end
    hardware_uri
  end

  #  Chef oneview provisioning
  def create_machine(action_handler, machine_spec, machine_options)
    host_name = machine_options[:driver_options][:host_name]
    server_template = machine_options[:driver_options][:server_template]

    auth_tokens # Login (to both Altair and OneView)

    # Check if profile exists first
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")

    if matching_profiles['count'] > 0
      profile = matching_profiles['members'].first
      power_on(action_handler, machine_spec, machine_options, profile['serverHardwareUri']) # Make sure server is started
      return profile
    end


    #  Get HPOVProfile by name (to see if it already exists)
    #  For 120 verion of Oneview , we are going to retrive a predefined unassociated server profile
    templates = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{server_template}'&sort=name:asc")

    template_uri          = templates['members'].first['uri']
    serverHardwareTypeUri = templates['members'].first['serverHardwareTypeUri']
    enclosureGroupUri     = templates['members'].first['enclosureGroupUri']

    # Get availabe (and compatible) HP OV server blades. Take first one.
    #blades = rest_api(:oneview, :get, "/rest/server-hardware?sort=name:asc&filter=serverProfileUri=null&filter=serverHardwareTypeUri='#{serverHardwareTypeUri}'&filter=serverGroupUri='#{enclosureGroupUri}'")
    blades = rest_api(:oneview, :get, "/rest/server-hardware?sort=name:asc&filter=serverHardwareTypeUri='#{serverHardwareTypeUri}'&filter=serverGroupUri='#{enclosureGroupUri}'")
    raise "Error! No available blades that are compatible with the server profile!" unless blades['count'] > 0
    chosen_blade = nil
    blades['members'].each do |member|
      if (member["state"] != "ProfileApplied" &&  member["state"] != "ApplyingProfile")
        chosen_blade = member
        break
      end
    end
    if !chosen_blade # TODO
      # Every bay is full and no more machines can be allocated
      raise "No more blades are available for provisioning!"
    end

    power_off(action_handler, machine_spec, machine_options, chosen_blade['uri'])
    # New-HPOVProfileFromTemplate
    # Create new profile instance from template
    action_handler.perform_action "Initialize creation of server template for #{machine_spec.name}" do
      action_handler.report_progress "INFO: Initializing creation of server template for #{machine_spec.name}"

      new_template_profile = rest_api(:oneview, :get, "#{template_uri}")

      # Take response, add name & hardware uri, and post back to /rest/server-profiles
      new_template_profile['name'] = host_name
      new_template_profile['uri'] = nil
      new_template_profile['serialNumber'] = nil
      new_template_profile['uuid'] = nil
      new_template_profile['connections'].each do |c|
        c['wwnn'] = nil
        c['wwpn'] = nil
        c['mac']  = nil
      end

      new_template_profile['serverHardwareUri'] = chosen_blade['uri']
      task = rest_api(:oneview, :post, "/rest/server-profiles", { 'body'=>new_template_profile })
      task_uri = task['uri']
      # Poll task resource to see when profile has finished being applied
      60.times do # Wait for up to 5 min
        matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
        break if matching_profiles['count'] > 0
        print "."
        sleep 5
      end
      unless matching_profiles['count'] > 0
        task = rest_api(:oneview, :get, task_uri)
        raise "Server template coudln't be applied! #{task['taskStatus']}. #{task['taskErrors'].first['message']}"
      end
    end
    return matching_profiles['members'].first
  end


  # Use Altair to install OS
  def customize_machine(action_handler, machine_spec, machine_options, profile)
    auth_tokens # Login (to both Altair and OneView)

    # Wait for server profile to finish building
    unless profile['state'] == 'Normal'
      action_handler.perform_action "Wait for #{machine_spec.name} server to start and profile to be applied" do
        action_handler.report_progress "INFO: Waiting for #{machine_spec.name} server to start and profile to be applied"
        task_uri = profile['taskUri']
        build_server_template_task = rest_api(:oneview, :get, task_uri)
        # Poll task resource to see when profile has finished being applied
        240.times do # Wait for up to 40 min
          build_server_template_task = rest_api(:oneview, :get, task_uri)
          break if build_server_template_task['taskState'].downcase == 'completed'
          if build_server_template_task['taskState'].downcase == 'error'
            server_template = machine_options[:driver_options][:server_template]
            raise "Error creating server profile from template #{server_template}: #{build_server_template_task['taskErrors'].first['message']}"
          end
          print "."
          sleep 10
        end
        raise "Timed out waiting for server to start and profile to be applied" unless build_server_template_task['taskState'].downcase == "completed"
      end
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number']) # Refresh profile
      raise "Server profile state '#{profile['state']}' not 'Normal'" unless profile['state'] == 'Normal'
    end

    # Make sure server is started
    power_on(action_handler, machine_spec, machine_options, profile['serverHardwareUri'])

    # Get Altair servers to poll and wait until server PXE complete (to make sure Altair is available).
    my_server = nil
    action_handler.perform_action "Wait for #{machine_spec.name} to boot" do
      action_handler.report_progress "INFO: Waiting for #{machine_spec.name} to PXE boot. This may take a while..."
      360.times do # Wait for up to 1 hr
        os_deployment_servers = rest_api(:altair, :get, '/rest/os-deployment-servers')

        # TODO: Maybe check for opswLifecycle = 'UNPROVISIONED' instead of serialNumber existance
        os_deployment_servers['members'].each do |server|
          if server['serialNumber'] == profile['serialNumber']
            my_server = server
            break
          end
        end
        break if !my_server.nil?
        print "."
        sleep 10
      end
      raise "Timeout waiting for server #{machine_spec.name} to register with Altair" if my_server.nil?
    end

    # Consume any custom attributes that were specified
    if machine_options[:driver_options][:custom_attributes]
      curr_server = rest_api(:altair, :get, my_server['uri'])
      machine_options[:driver_options][:custom_attributes].each do |key, val|
        curr_server['customAttributes'].push ({
          "values"=>[{"scope"=>"server", "value"=> val.to_s}], 
          "key" => key.to_s
        })
      end
      options = { 'body'=> curr_server }
      rest_api(:altair, :put, my_server['uri'], options)
    end

    # Run OS install on a server
    unless my_server['opswLifecycle'] == 'MANAGED' # Skip if already in MANAGED state
      os_build = machine_options[:driver_options][:os_build]
      action_handler.perform_action "Install OS: #{os_build} on #{machine_spec.name}" do
        action_handler.report_progress "INFO: Installing OS: #{os_build} on #{machine_spec.name}"
        # Get os-deployment-build-plans
        build_plan_uri = nil
        os_deployment_build_plans = rest_api(:altair, :get, '/rest/os-deployment-build-plans')
        os_deployment_build_plans['members'].each do |bp|
          if bp['name'] == os_build
            build_plan_uri = bp['uri']
            break
          end
        end
        raise "OS build plan #{os_build} not found!" if build_plan_uri.nil?

        # Do the OS deployment
        options = { 'body' => {
          'osbpUris' => [build_plan_uri],
          'serverData' => [{'serverUri'=> my_server['uri'] }]
        }}
        os_deployment_task = rest_api(:altair, :post, '/rest/os-deployment-jobs/?force=true', options)
        os_deployment_task_uri = os_deployment_task['uri']
        720.times do # Wait for up to 2 hr
          os_deployment_task = rest_api(:altair, :get, os_deployment_task_uri, options) # TODO: Need options?
          break if os_deployment_task['running'] == 'false'
          print "."
          sleep 10
        end
        unless os_deployment_task['state'] == 'STATUS_SUCCESS'
          raise "Error running OS build plan #{os_build}: #{os_deployment_task['jobResult'].first['jobMessage']}\n#{os_deployment_task['jobResult'].first['jobResultErrorDetails']}"
        end
      end
    end

    # Perform network personalization
    action_handler.perform_action "Perform network personalization on #{machine_spec.name}" do
      action_handler.report_progress "INFO: Performing network personalization on #{machine_spec.name}"
      nics = []
      if machine_options[:driver_options][:connections]
        machine_options[:driver_options][:connections].each do |id, data|
          c = data
          c[:macAddress]   = profile['connections'].select {|c| c['id']==id}.first['mac']
          c[:mask]       ||= machine_options[:driver_options][:mask]
          c[:dhcp]       ||= machine_options[:driver_options][:dhcp] || false
          c[:gateway]    ||= machine_options[:driver_options][:gateway]
          c[:dns]        ||= machine_options[:driver_options][:dns]
          c[:ip4Address] ||= machine_options[:driver_options][:ip_address]
          nics.push c
        end
      end
      options = { 'body'=> [{
        'serverUri' => my_server['uri'],
        'personalityData' => {
          'hostName'   => machine_options[:driver_options][:host_name],
          'domainType' => machine_options[:driver_options][:domainType],
          'domainName' => machine_options[:driver_options][:domainName],
          'nics'       => nics
        }
      }] }
      network_personalization_task = rest_api(:altair, :put, '/rest/os-deployment-apxs/personalizeserver', options)
      network_personalization_task_uri = network_personalization_task['uri']
      60.times do # Wait for up to 10 min
        network_personalization_task = rest_api(:altair, :get, network_personalization_task_uri, options)
        break if network_personalization_task['running'] == 'false'
        print "."
        sleep 10
      end
      unless network_personalization_task['state'] == 'STATUS_SUCCESS'
        raise "Error performing network personalization: #{network_personalization_task['jobResult'].first['jobResultLogDetails']}\n#{network_personalization_task['jobResult'].first['jobResultErrorDetails']}"
      end
    end
    #   Get all, search for yours.  If not there or if it's in uninitialized state, pull again
    my_server_uri = my_server['uri']
    30.times do # Wait for up to 5 min
      my_server = rest_api(:altair, :get, my_server_uri)
      break if my_server['opswLifecycle'] == 'MANAGED'
      print "."
      sleep 10
    end

    raise "Timeout waiting for server #{machine_spec.name} to finish network personalization" if my_server['opswLifecycle'] != 'MANAGED'
    return my_server
  end


  def destroy_altair_server(action_handler, machine_spec)
    my_server = get_altair_server_by_sn(machine_spec.reference['serial_number'])
    return false if my_server.nil? || my_server['uri'].nil?
    
    action_handler.perform_action "Delete server #{machine_spec.name} from Altair" do
      task = rest_api(:altair, :delete, my_server['uri']) # TODO: This returns nil instead of task info

      if task['uri']
        task_uri = task['uri']
        90.times do # Wait for up to 15 minutes
          task = rest_api(:altair, :get, task_uri)
          break if task['taskState'].downcase == "completed"
          print "."
          sleep 10
        end
        raise "Deleting os deployment server #{machine_spec.name} at altair failed!" unless task['taskState'].downcase == "completed"
      end
    end
  end


  def destroy_oneview_profile(action_handler, machine_spec, profile=nil)
    profile ||= get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
    
    hardware_info = rest_api(:oneview, :get, profile['serverHardwareUri'])
    unless hardware_info.nil?
      action_handler.perform_action "Delete server #{machine_spec.name} from oneview" do
        action_handler.report_progress "INFO: Deleting server profile #{machine_spec.name}"
        task = rest_api(:oneview, :Delete, "#{profile['uri']}")
        task_uri = task['uri']

        60.times do # Wait for up to 10 minutes
          task = rest_api(:oneview, :get, task_uri)
          break if task['taskState'].downcase == "completed"
          print "."
          sleep 10
        end
        raise "Deleting server profile #{machine_spec.name} failed!" unless task['taskState'].downcase == "completed"
      end
    else
      action_handler.report_progress "INFO: #{machine_spec.name} is already deleted."
    end
  end
  
end
