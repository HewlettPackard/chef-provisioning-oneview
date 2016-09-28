module OneviewChefProvisioningDriver
  # Handles OS install and network configuration
  module CustomizeMachine
    # Use ICSP to install OS
    def customize_machine(action_handler, machine_spec, machine_options, profile)
      machine_name = machine_spec.name
      # Wait for server profile to finish building
      wait_for_profile(action_handler, machine_name, profile)
      profile.refresh

      # Configure SAN storage (if applicable)
      enable_boot_from_san(action_handler, machine_name, profile) unless machine_spec.reference['network_personalitation_finished']

      # Make sure server is started
      profile.get_server_hardware.power_on

      return if @icsp_ignore == true

      # Get ICSP servers to poll and wait until server PXE complete (to make sure ICSP is available).
      my_server = nil
      action_handler.perform_action "Wait for #{machine_name} to boot into HP Intelligent Provisioning" do
        action_handler.report_progress "INFO: Waiting for #{machine_name} to PXE boot into HP Intelligent Provisioning"
        360.times do # Wait for up to 1 hr
          my_server = get_icsp_server_by_sn(profile['serialNumber'])
          break unless my_server.nil?
          print '.'
          sleep 10
        end
        raise "Timeout waiting for server #{machine_name} to register with ICSP" if my_server.nil?
      end

      icsp_configure_nic_teams(machine_options, profile)

      icsp_set_custom_attributes(machine_options, my_server)

      icsp_run_os_install(action_handler, machine_spec, machine_options, my_server, profile)

      # Customize networking
      if !machine_spec.reference['network_personalitation_finished'] || machine_options[:driver_options][:force_network_update]

        icsp_configure_networking(action_handler, machine_spec, machine_options, my_server, profile)

        # Switch deploy networks to post-deploy networks if specified
        if machine_options[:driver_options][:connections]
          available_networks = profile.available_networks
          machine_options[:driver_options][:connections].each do |id, data|
            next unless data && data[:net] && data[:deployNet]
            action_handler.perform_action "Perform network flipping on #{machine_name}, connection #{id}" do
              action_handler.report_progress "INFO: Performing network flipping on #{machine_name}, connection #{id}"
              deploy_network = available_networks['ethernetNetworks'].find { |n| n['name'] == data[:deployNet] }
              new_network = available_networks['ethernetNetworks'].find { |n| n['name'] == data[:net] }
              raise "Failed to perform network flipping on #{machine_name}, connection #{id}. '#{data[:net]}' network not found" if new_network.nil?
              raise "Failed to perform network flipping on #{machine_name}, connection #{id}. '#{data[:deployNet]}' network not found" if deploy_network.nil?
              profile.refresh
              profile['connections'].find { |c| c['networkUri'] == deploy_network['uri'] }['networkUri'] = new_network['uri']
              profile.update
            end
          end
        end
        machine_spec.reference['network_personalitation_finished'] = true
      end

      my_server = rest_api(:icsp, :get, my_server['uri'])
    end
  end
end
