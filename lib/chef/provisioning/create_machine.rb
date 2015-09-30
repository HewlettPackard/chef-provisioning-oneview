module CreateMachine
  private

  # Chef oneview provisioning
  def create_machine(action_handler, machine_spec, machine_options)
    host_name = machine_options[:driver_options][:host_name]

    auth_tokens # Login (to both ICSP and OneView)

    # Check if profile exists first
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
    if matching_profiles['count'] > 0
      profile = matching_profiles['members'].first
      power_on(action_handler, machine_spec, profile['serverHardwareUri']) # Make sure server is started
      return profile
    end

    # Search for OneView Template by name
    template = get_oneview_template(machine_options[:driver_options][:server_template])

    # Get first availabe (and compatible) HP OV server blade
    chosen_blade = available_hardware_for_template(template)

    power_off(action_handler, machine_spec, chosen_blade['uri'])

    # Create new profile instance from template
    action_handler.perform_action "Initialize creation of server profile for #{machine_spec.name}" do
      action_handler.report_progress "INFO: Initializing creation of server profile for #{machine_spec.name}"

      # Take template, add name & hardware uri, and post back to /rest/server-profiles
      template['name'] = host_name
      template['uri'] = nil
      template['serialNumber'] = nil
      template['uuid'] = nil
      template['taskUri'] = nil
      template['connections'].each do |c|
        c['wwnn'] = nil
        c['wwpn'] = nil
        c['mac']  = nil
      end

      template['serverHardwareUri'] = chosen_blade['uri']
      options = { 'body' => template }
      options['X-API-Version'] = 200 if @current_oneview_api_version >= 200 && template['type'] == 'ServerProfileV5'
      task = rest_api(:oneview, :post, '/rest/server-profiles', options)
      task_uri = task['uri']
      fail "Failed to create OneView server profile #{host_name}. Details: " unless task_uri
      # Wait for profile to be created
      60.times do # Wait for up to 5 min
        matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
        return matching_profiles['members'].first if matching_profiles['members'].first
        print '.'
        sleep 5
      end
      task = rest_api(:oneview, :get, task_uri)
      fail "Server profile couldn't be created! #{task['taskStatus']}. #{task['taskErrors'].first['message']}"
    end
  end
end
