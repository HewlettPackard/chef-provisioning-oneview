module CustomizeMachine
  private

  # Use ICSP to install OS
  def customize_machine(action_handler, machine_spec, machine_options, profile)
    # Wait for server profile to finish building
    wait_for_profile(action_handler, machine_spec, machine_options, profile)

    # Configure SAN storage (if applicable)
    enable_boot_from_san(action_handler, machine_spec, profile) unless machine_spec.reference['network_personalitation_finished']

    # Make sure server is started
    power_on(action_handler, machine_spec, profile['serverHardwareUri'])

    # Get ICSP servers to poll and wait until server PXE complete (to make sure ICSP is available).
    my_server = nil
    action_handler.perform_action "Wait for #{machine_spec.name} to boot into HP Intelligent Provisioning" do
      action_handler.report_progress "INFO: Waiting for #{machine_spec.name} to PXE boot into HP Intelligent Provisioning"
      360.times do # Wait for up to 1 hr
        my_server = get_icsp_server_by_sn(profile['serialNumber'])
        break if !my_server.nil?
        print '.'
        sleep 10
      end
      raise "Timeout waiting for server #{machine_spec.name} to register with ICSP" if my_server.nil?
    end

    icsp_configure_nic_teams(machine_options, profile)

    icsp_set_custom_attributes(machine_options, my_server)

    icsp_run_os_install(action_handler, machine_spec, machine_options, my_server, profile)

    # Customize networking
    if !machine_spec.reference['network_personalitation_finished'] || machine_options[:driver_options][:force_network_update]

      icsp_configure_networking(action_handler, machine_spec, machine_options, my_server, profile)

      # Switch deploy networks to post-deploy networks if specified
      if machine_options[:driver_options][:connections]
        available_networks = rest_api(:oneview, :get, "/rest/server-profiles/available-networks?serverHardwareTypeUri=#{profile['serverHardwareTypeUri']}&enclosureGroupUri=#{profile['enclosureGroupUri']}")
        machine_options[:driver_options][:connections].each do |id, data|
          next unless data && data[:net] && data[:deployNet]
          action_handler.report_progress "INFO: Performing network flipping on #{machine_spec.name}, connection #{id}"
          deploy_network = available_networks['ethernetNetworks'].find {|n| n['name'] == data[:deployNet] }
          new_network = available_networks['ethernetNetworks'].find {|n| n['name'] == data[:net] }
          raise "Failed to perform network flipping on #{machine_spec.name}, connection #{id}. '#{data[:net]}' network not found" if new_network.nil?
          raise "Failed to perform network flipping on #{machine_spec.name}, connection #{id}. '#{data[:deployNet]}' network not found" if deploy_network.nil?
          profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
          profile['connections'].find {|c| c['networkUri'] == deploy_network['uri'] }['networkUri'] = new_network['uri']
          options = { 'body' => profile }
          task = rest_api(:oneview, :put, profile['uri'], options)
          raise "Failed to perform network flipping on #{machine_spec.name}. Details: #{task['message'] || task}" unless task['uri']
          task = oneview_wait_for(task['uri']) # Wait up to 10 min
          raise "Timed out waiting for network flipping on #{machine_spec.name}" if task == false
          raise "Error performing network flip on #{machine_spec.name}. Response: #{task}" unless task == true
        end
      end
      machine_spec.reference['network_personalitation_finished'] = true
    end

    my_server = rest_api(:icsp, :get, my_server['uri'])
  end
end
