module OneviewChefProvisioningDriver
  # Handles allocation of OneView ServerProfile
  module CreateMachine
    # Allocate OneView server profile
    def create_machine(action_handler, machine_name, machine_options)
      host_name = machine_options[:driver_options][:host_name] || machine_name
      profile_name = machine_options[:driver_options][:profile_name] || host_name

      # Check if profile exists first
      matching_profile = OneviewSDK::ServerProfile.find_by(@ov, name: host_name).first
      return matching_profile if matching_profile

      # Search for OneView Template or Profile by name
      template_name = machine_options[:driver_options][:server_template]
      profile = profile_from_template(template_name, profile_name)

      # Get first availabe (and compatible) HP OV server blade.
      # If a server_location has been specified, uses that
      hw = available_hardware_for_profile(profile, machine_options[:driver_options][:server_location])

      action_handler.perform_action "Power off server #{hw['name']} for machine '#{machine_name}'" do
        action_handler.report_progress "INFO: Powering off server #{hw['name']} for machine '#{machine_name}'"
        hw.power_off
      end

      # Create new ServerProfile from the template
      action_handler.perform_action "Create server profile for #{machine_name}" do
        action_handler.report_progress "INFO: Creating server profile for #{machine_name}"
        profile.set_server_hardware(hw)
        update_san_info(machine_name, profile)
        response = @ov.rest_post(profile.class::BASE_URI, { 'body' => profile.data }, profile.api_version)
        unless response.code.to_i == 202
          task = JSON.parse(response.body)
          raise "Server profile couldn't be created! #{task['taskStatus']}. #{task['taskErrors'].first['message'] rescue nil}"
        end
        60.times do # Wait for up to 5 min for profile to appear in OneView
          return profile if profile.retrieve!
          task = @ov.response_handler(@ov.rest_get(response.header['location'] || JSON.parse(response.body)['uri']))
          break if task['taskState'] == 'Error'
          print '.'
          sleep 5
        end
        raise "Server profile couldn't be created! #{task['taskStatus']}. #{task['taskErrors'].first['message'] rescue nil}"
      end
      profile
    end
  end
end
