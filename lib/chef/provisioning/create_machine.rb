module CreateMachine
  private

  # Chef oneview provisioning
  def create_machine(action_handler, machine_spec, machine_options)
    host_name = machine_options[:driver_options][:host_name]

    # Check if profile exists first
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
    if matching_profiles['count'] > 0
      profile = matching_profiles['members'].first
      return profile
    end

    # Search for OneView Template by name
    template = get_oneview_template(machine_options[:driver_options][:server_template])

    # Get first availabe (and compatible) HP OV server blade
    # If a server_location has been specified, uses that
    chosen_blade = available_hardware_for_template(template, machine_options[:driver_options][:server_location])

    power_off(action_handler, machine_spec, chosen_blade['uri'])

    # Create new profile instance from template
    action_handler.perform_action "Initialize creation of server profile for #{machine_spec.name}" do
      action_handler.report_progress "INFO: Initializing creation of server profile for #{machine_spec.name}"

      # Add name & hardware uri to template
      template['name'] = host_name
      template['serverHardwareUri'] = chosen_blade['uri']

      update_san_info(machine_spec, template)

      # Post back to /rest/server-profiles
      options = { 'body' => template }
      options['X-API-Version'] = 200 if @current_oneview_api_version >= 200 && template['type'] == 'ServerProfileV5'
      task = rest_api(:oneview, :post, '/rest/server-profiles', options)
      task_uri = task['uri']
      raise "Failed to create OneView server profile #{host_name}. Details: " unless task_uri
      # Wait for profile to appear
      60.times do # Wait for up to 5 min
        matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
        return matching_profiles['members'].first if matching_profiles['members'].first
        print '.'
        sleep 5
      end
      task = rest_api(:oneview, :get, task_uri)
      raise "Server profile couldn't be created! #{task['taskStatus']}. #{task['taskErrors'].first['message']}"
    end
  end
end
