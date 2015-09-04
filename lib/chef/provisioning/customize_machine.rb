module CustomizeMachine
  private

  # Use ICSP to install OS
  def customize_machine(action_handler, machine_spec, machine_options, profile)
    auth_tokens # Login (to both ICSP and OneView)

    # Wait for server profile to finish building
    unless profile['state'] == 'Normal'
      action_handler.perform_action "Wait for #{machine_spec.name} server to start and profile to be applied" do
        action_handler.report_progress "INFO: Waiting for #{machine_spec.name} server to start and profile to be applied"
        task = oneview_wait_for(profile['taskUri'], 240) # Wait up to 40 min for profile to be created
        fail 'Timed out waiting for server to start and profile to be applied' if task == false
        unless task == true
          server_template = machine_options[:driver_options][:server_template]
          fail "Error creating server profile from template #{server_template}: #{task['taskErrors'].first['message']}"
        end
      end
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number']) # Refresh profile
      fail "Server profile state '#{profile['state']}' not 'Normal'" unless profile['state'] == 'Normal'
    end

    # Make sure server is started
    power_on(action_handler, machine_spec, profile['serverHardwareUri'])

    # Get ICSP servers to poll and wait until server PXE complete (to make sure ICSP is available).
    my_server = nil
    action_handler.perform_action "Wait for #{machine_spec.name} to boot" do
      action_handler.report_progress "INFO: Waiting for #{machine_spec.name} to PXE boot. This may take a while..."
      360.times do # Wait for up to 1 hr
        my_server = get_icsp_server_by_sn(profile['serialNumber'])
        break if !my_server.nil?
        print '.'
        sleep 10
      end
      fail "Timeout waiting for server #{machine_spec.name} to register with ICSP" if my_server.nil?
    end

    # Consume any custom attributes that were specified
    if machine_options[:driver_options][:custom_attributes]
      curr_server = rest_api(:icsp, :get, my_server['uri'])
      machine_options[:driver_options][:custom_attributes].each do |key, val|
        curr_server['customAttributes'].push({
          'values' => [{ 'scope' => 'server',  'value' => val.to_s }],
          'key' => key.to_s
        })
      end
      options = { 'body' => curr_server }
      rest_api(:icsp, :put, my_server['uri'], options)
    end

    # Run OS install on a server
    unless my_server['opswLifecycle'] == 'MANAGED' # Skip if already in MANAGED state
      os_build = machine_options[:driver_options][:os_build]
      action_handler.perform_action "Run: '#{os_build}' OS Build Plan on #{machine_spec.name}" do
        action_handler.report_progress "INFO: Running: '#{os_build}' OS Build Plan on #{machine_spec.name}"
        # Get os-deployment-build-plans
        build_plan_uri = nil
        os_deployment_build_plans = rest_api(:icsp, :get, '/rest/os-deployment-build-plans')
        os_deployment_build_plans['members'].each do |bp|
          if bp['name'] == os_build
            build_plan_uri = bp['uri']
            break
          end
        end
        fail "OS build plan #{os_build} not found!" if build_plan_uri.nil?

        # Do the OS deployment
        options = { 'body' => {
          'osbpUris' => [build_plan_uri],
          'serverData' => [{ 'serverUri' => my_server['uri'] }]
        } }
        os_deployment_task = rest_api(:icsp, :post, '/rest/os-deployment-jobs/?force=true', options)
        os_deployment_task_uri = os_deployment_task['uri']
        fail "Failed to start OS Deployment Job. Details: #{os_deployment_task['details']}" unless os_deployment_task_uri
        # task = icsp_wait_for(os_deployment_task_uri, 720, sleep_seconds = 10)
        # fail "Error running OS build plan #{os_build}: #{task['jobResult'].first['jobMessage']}\n#{task['jobResult'].first['jobResultErrorDetails']}" unless task == true
        720.times do # Wait for up to 2 hr
          os_deployment_task = rest_api(:icsp, :get, os_deployment_task_uri)
          break if os_deployment_task['running'] == 'false'
          print '.'
          sleep 10
        end
        unless os_deployment_task['state'] == 'STATUS_SUCCESS'
          fail "Error running OS build plan #{os_build}: #{os_deployment_task['jobResult'].first['jobMessage']}\n#{os_deployment_task['jobResult'].first['jobResultErrorDetails']}"
        end
      end
    end

    require 'pry'
    # Perform network personalization
    if !machine_spec.reference['network_personalitation_finished']
      action_handler.perform_action "Perform network personalization on #{machine_spec.name}" do
        action_handler.report_progress "INFO: Performing network personalization on #{machine_spec.name}"
        nics = []
        if machine_options[:driver_options][:connections]
          machine_options[:driver_options][:connections].each do |id, data|
            c = data
            next if c[:dhcp] == true
            begin
              c[:macAddress]   = profile['connections'].find {|x| x['id'] == id}['mac']
            rescue NoMethodError
              ids = []
              profile['connections'].each {|x| ids.push x['id']}
              raise "Could not find connection id #{id} for #{profile['name']}. Available connection ids are: #{ids}. Please make sure the connection ids map to those on OneView."
            end
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
        network_personalization_task = rest_api(:icsp, :put, '/rest/os-deployment-apxs/personalizeserver', options)
        fail "Could not perform network personalization task:\n#{network_personalization_task.to_json}" unless network_personalization_task['uri']
        network_personalization_task_uri = network_personalization_task['uri']
        60.times do # Wait for up to 10 min
          network_personalization_task = rest_api(:icsp, :get, network_personalization_task_uri, options)
          break if network_personalization_task['running'] == 'false'
          print '.'
          sleep 10
        end
        unless network_personalization_task['state'] == 'STATUS_SUCCESS'
          fail "Error performing network personalization: #{network_personalization_task['jobResult'].first['jobResultLogDetails']}\n#{network_personalization_task['jobResult'].first['jobResultErrorDetails']}"
        end

        # Check if task succeeds and ICsp IP config matches machine options
        requested_ips = []
        machine_options[:driver_options][:connections].each do |_id, c|
          requested_ips.push c[:ip4Address] if c[:ip4Address] && c[:dhcp] == false
        end
        60.times do
          my_server_connections = rest_api(:icsp, :get, my_server['uri'])['interfaces']
          my_server_connections.each { |c| requested_ips.delete c['ipv4Addr'] }
          break if requested_ips.empty?
          print '.'
          sleep 10
        end
        fail 'Error setting up ips correctly in ICSP' unless requested_ips.empty?

        # Switch deploy networks to post-deploy networks if specified
        if machine_options[:driver_options][:connections]
          available_networks = rest_api(:oneview, :get, "/rest/server-profiles/available-networks?serverHardwareTypeUri=#{profile['serverHardwareTypeUri']}&enclosureGroupUri=#{profile['enclosureGroupUri']}")
          machine_options[:driver_options][:connections].each do |id, data|
            next unless data[:net] && data[:deployNet]
            action_handler.report_progress "INFO: Performing network flipping on #{machine_spec.name}, connection #{id}"
            deploy_network = available_networks['ethernetNetworks'].find {|n| n['name'] == data[:deployNet] }
            new_network = available_networks['ethernetNetworks'].find {|n| n['name'] == data[:net] }
            fail "Failed to perform network flipping on #{machine_spec.name}, connection #{id}. '#{data[:net]}' network not found" if new_network.nil?
            fail "Failed to perform network flipping on #{machine_spec.name}, connection #{id}. '#{data[:deployNet]}' network not found" if deploy_network.nil?
            profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
            profile['connections'].find {|c| c['networkUri'] == deploy_network['uri'] }['networkUri'] = new_network['uri']
            options = { 'body' => profile }
            rest_api(:oneview, :put, profile['uri'], options)
          end
        end
        machine_spec.reference['network_personalitation_finished'] = true
      end
    end

    # Get all, search for yours.  If not there or if it's in uninitialized state, pull again
    my_server_uri = my_server['uri']
    30.times do # Wait for up to 5 min
      my_server = rest_api(:icsp, :get, my_server_uri)
      break if my_server['opswLifecycle'] == 'MANAGED'
      print '.'
      sleep 10
    end

    fail "Timeout waiting for server #{machine_spec.name} to finish network personalization" if my_server['opswLifecycle'] != 'MANAGED'
    my_server
  end
end
