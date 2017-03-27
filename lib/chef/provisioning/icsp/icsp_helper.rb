require_relative 'rest'
require_relative 'api_v104'

module OneviewChefProvisioningDriver
  # Helpers for ICSP actions
  module IcspHelper
    include RestAPI
    include ICspAPIv104

    def get_icsp_api_version
      begin
        version = rest_api(:icsp, :get, '/rest/version', 'Content-Type' => :none, 'X-API-Version' => :none, 'auth' => :none)['currentVersion']
        raise "Couldn't get API version" unless version
        if version.class != Fixnum
          version = version.to_i
          raise 'API version type mismatch' if !version > 0
        end
      rescue
        puts 'Failed to get ICSP API version. Setting to default (102)'
        version = 102
      end
      version
    end

    def login_to_icsp
      path = '/rest/login-sessions'
      options = {
        'body' => {
          'userName' => @icsp_username,
          'password' => @icsp_password,
          'authLoginDomain' => 'LOCAL'
        }
      }
      response = rest_api(:icsp, :post, path, options)
      return response['sessionID'] if response['sessionID']
      raise("\nERROR! Couldn't log into ICSP server at #{@icsp_base_url}. Response:\n#{response}")
    end

    def get_icsp_server_by_sn(serial_number)
      raise 'Must specify a serialNumber!' if serial_number.nil? || serial_number.empty?
      search_result = rest_api(:icsp, :get,
        "/rest/index/resources?category=osdserver&query='osdServerSerialNumber:\"#{serial_number}\"'")['members'] rescue nil
      if search_result && search_result.size == 1 && search_result.first['attributes']['osdServerSerialNumber'] == serial_number
        my_server_uri = search_result.first['uri']
        my_server = rest_api(:icsp, :get, my_server_uri)
      end
      unless my_server && my_server['uri']
        os_deployment_servers = rest_api(:icsp, :get, '/rest/os-deployment-servers')
        # Pick the relevant os deployment server from icsp
        my_server = nil
        os_deployment_servers['members'].each do |server|
          if server['serialNumber'] == serial_number
            my_server = server
            break
          end
        end
      end
      my_server
    end

    def icsp_wait_for(task_uri, wait_iterations = 60, sleep_seconds = 10)
      raise 'Must specify a task_uri!' if task_uri.nil? || task_uri.empty?
      wait_iterations.times do
        task = rest_api(:icsp, :get, task_uri)
        if task['taskState']
          case task['taskState'].downcase
          when 'completed'
            return true
          when 'error', 'killed', 'terminated'
            return task
          end
        elsif task['running'] == 'false' && task['jobResult']
          if task['state'] == 'STATUS_SUCCESS'
            return true
          else
            return task
          end
        end
        print '.'
        sleep sleep_seconds
      end
      false
    end

    # Consume and set any custom attributes that were specified
    def icsp_set_custom_attributes(machine_options, my_server)
      if machine_options[:driver_options][:custom_attributes]
        curr_server = rest_api(:icsp, :get, my_server['uri'])
        machine_options[:driver_options][:custom_attributes].each do |key, val|
          curr_server['customAttributes'].push(
            'values' => [{ 'scope' => 'server', 'value' => val.to_s }],
            'key' => key.to_s
          )
        end
        options = { 'body' => curr_server }
        rest_api(:icsp, :put, my_server['uri'], options)
      end
    end

    def icsp_run_os_install(action_handler, machine_spec, machine_options, my_server, profile)
      return if my_server['state'] == 'OK' # Skip if the OS has already been deployed

      # Wait for my_server['state'] to be in MAINTENANCE mode
      if my_server['state'] != 'MAINTENANCE'
        action_handler.perform_action "Wait for #{machine_spec.name} to go into maintenance mode in ICsp" do
          action_handler.report_progress "INFO: Waiting for #{machine_spec.name} to go into maintenance mode in ICsp"
          120.times do # Wait for up to 20 min
            my_server = get_icsp_server_by_sn(profile['serialNumber'])
            break if my_server['state'] != 'MAINTENANCE'
            print '.'
            sleep 10
          end
          raise "Timed out waiting for #{machine_spec.name} to go into maintenance mode in ICsp. State: #{my_server['state']}" unless my_server['state'] == 'MAINTENANCE'
        end
      end

      # Get the specified OS Build Plan(s)
      os_builds = machine_options[:driver_options][:os_build]
      os_builds = [os_builds] if os_builds.class == String
      build_plan_uris = []
      action_handler.perform_action "Get OS Build Plan(s) info for #{machine_spec.name}" do
        action_handler.report_progress "INFO: Getting OS Build Plan(s) for #{machine_spec.name}"
        os_builds.each do |os_build|
          uri = "/rest/index/resources?userQuery=\"'#{os_build}'\"&category=osdbuildplan"
          while uri
            matching_plans = rest_api(:icsp, :get, uri)
            raise "Search failed for OSBP '#{os_build}'. Response: #{matching_plans}" unless matching_plans['members']
            build_plan_uri = matching_plans['members'].find { |bp| bp['name'] == os_build }['uri'] rescue nil
            break unless build_plan_uri.nil?
            uri = URI.unescape(matching_plans['nextPageUri']) rescue nil
          end
          raise "OS build plan #{os_build} not found!" if build_plan_uri.nil?
          build_plan_uris.push build_plan_uri
        end
      end

      # Build options for the OS deployment
      options = {}
      options['X-API-Version'] = 104 if @current_icsp_api_version.between?(104, 108)
      options['body'] = {
        'osbpUris' => build_plan_uris,
        'serverData' => [{
          'serverUri' => my_server['uri']
        }]
      }

      # Do the OS deployment
      action_handler.perform_action "Run: #{os_builds} OS Build Plan(s) on #{machine_spec.name}" do
        action_handler.report_progress "INFO: Running: #{os_builds} OS Build Plan(s) on #{machine_spec.name}"
        task = rest_api(:icsp, :post, '/rest/os-deployment-jobs/?force=true', options)
        task_uri = task['uri']
        raise "Failed to start OS Deployment Job. Details: #{task['details'] || task['message'] || task}" unless task_uri
        task = icsp_wait_for(task_uri, 720)
        raise "Error running OS build plan(s) #{os_builds}: #{task['jobResult'].first['jobMessage']}\n#{task['jobResult'].first['jobResultErrorDetails']}" unless task == true
      end
    end

    def icsp_configure_networking(action_handler, machine_spec, machine_options, my_server, profile)
      return if machine_options[:driver_options][:skip_network_configuration] == true
      action_handler.perform_action "Configure networking on #{machine_spec.name}" do
        action_handler.report_progress "INFO: Configuring networking on #{machine_spec.name}"
        personality_data = icsp_build_personality_data(machine_options, profile)
        options = {}
        options['X-API-Version'] = 104 if @current_icsp_api_version.between?(104, 108)
        options['body'] = {
          'serverData' => [{
            'serverUri' => my_server['uri'],
            'personalityData' => personality_data
          }]
        }

        task = rest_api(:icsp, :post, '/rest/os-deployment-jobs/?force=true', options)
        task_uri = task['uri']
        raise "Failed to start network personalization job. Details: #{task['details'] || task['message'] || task}" unless task_uri
        task = icsp_wait_for(task_uri, 60) # Wait for up to 10 min
        raise "Error running network personalization job: #{task['jobResult'].first['jobMessage']}\n#{task['jobResult'].first['jobResultErrorDetails']}" unless task == true

        # Check if ICsp IP config matches machine options
        requested_ips = []
        machine_options[:driver_options][:connections].each do |_id, c|
          requested_ips.push c[:ip4Address] if c[:ip4Address] && c[:dhcp] == false
        end
        my_server_connections = []
        10.times do
          my_server_connections = rest_api(:icsp, :get, my_server['uri'])['interfaces']
          my_server_connections.each { |c| requested_ips.delete c['ipv4Addr'] }
          break if requested_ips.empty?
          print ','
          sleep 10
        end
        puts "\nWARN: The following IPs are not visible on ICsp, so they may not have gotten configured correctly: #{requested_ips}" unless requested_ips.empty?

        # Set interface data as normal node attributes
        my_server_connections.each do |c|
          c['oneViewId'] = profile['connections'].find { |x| x['mac'] == c['macAddr'] }['id'] rescue nil
        end
        machine_spec.data['normal']['icsp'] ||= {}
        machine_spec.data['normal']['icsp']['interfaces'] = my_server_connections
      end
    end

    # Build options for the network configuration
    def icsp_build_personality_data(machine_options, profile)
      nics = []
      if machine_options[:driver_options][:connections]
        machine_options[:driver_options][:connections].each do |id, data|
          c = Marshal.load(Marshal.dump(data))
          next unless c[:dhcp] || c[:dhcpv4] || c[:ip4Address] || c[:ipv6autoconfig] || c[:staticNetworks] # Invalid network or only switch networks specified
          c.delete_if { |k, _v| k.to_s == 'bootstrap' }
          begin
            c[:macAddress] = profile['connections'].find { |x| x['id'] == id }['mac']
          rescue NoMethodError
            ids = []
            profile['connections'].each { |x| ids.push x['id'] }
            raise "Could not find connection id #{id} for #{profile['name']}. Available connection ids are: #{ids}. Please make sure the connection ids map to those on OneView."
          end
          if @current_icsp_api_version.between?(104, 108)
            icsp_v104_parse_connection(machine_options, c)
          else
            c[:mask]    ||= machine_options[:driver_options][:mask]
            c[:dhcp]    ||= false
            c[:gateway] ||= machine_options[:driver_options][:gateway]
            c[:dns]     ||= machine_options[:driver_options][:dns]
          end
          nics.push c
        end
      end

      if @current_icsp_api_version.between?(104, 108)
        personality_data = icsp_v104_build_personality_data(machine_options, nics)
      else
        personality_data = {
          'hostName' => machine_options[:driver_options][:host_name],
          'domainType' => machine_options[:driver_options][:domainType],
          'domainName' => machine_options[:driver_options][:domainName],
          'nics' => nics
        }
      end
      personality_data
    end

    def destroy_icsp_server(action_handler, machine_spec)
      my_server = get_icsp_server_by_sn(machine_spec.reference['serial_number'])
      return false if my_server.nil? || my_server['uri'].nil?

      action_handler.perform_action "Delete server #{machine_spec.name} from ICSP" do
        task = rest_api(:icsp, :delete, my_server['uri']) # TODO: This returns nil instead of task info
        if task['uri']
          task_uri = task['uri']
          90.times do # Wait for up to 15 minutes
            task = rest_api(:icsp, :get, task_uri)
            break if task['taskState'].casecmp('completed') == 0
            print '.'
            sleep 10
          end
          raise "Deleting os deployment server #{machine_spec.name} at icsp failed!" unless task['taskState'].casecmp('completed') == 0
        end
      end
    end

    # Sets ICSP custom attributes to enable nic teaming
    def icsp_configure_nic_teams(machine_options, profile)
      return false if machine_options[:driver_options][:connections].nil?
      teams = {}

      machine_options[:driver_options][:connections].each do |id, options|
        next unless options.is_a?(Hash) && options[:team]
        raise "#{options[:team]}: Team names must not include hyphens" if options[:team].to_s.include?('-')
        teams[options[:team].to_s] ||= []
        begin
          mac = profile['connections'].find { |x| x['id'] == id }['mac']
          teams[options[:team].to_s].push mac
        rescue NoMethodError
          ids = []
          profile['connections'].each { |x| ids.push x['id'] }
          raise "Failed to configure nic teams: Could not find connection id #{id} for #{profile['name']}. Available connection ids are: #{ids}. Please make sure the connection ids map to those on OneView."
        end
      end
      team_strings = []
      teams.each do |name, macs|
        raise "Team '#{name}' must have at least 2 associated connections to form a NIC team" unless macs.size >= 2
        team_strings.push "#{name}-#{macs.join(',')}"
      end
      machine_options[:driver_options][:custom_attributes] ||= {}
      machine_options[:driver_options][:custom_attributes][:teams] = team_strings.join('|')
    end
  end
end
