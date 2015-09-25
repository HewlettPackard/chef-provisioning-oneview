module CreateMachine
  private

  # Chef oneview provisioning
  def create_machine(action_handler, machine_spec, machine_options)
    host_name = machine_options[:driver_options][:host_name]
    server_template = machine_options[:driver_options][:server_template]

    auth_tokens # Login (to both ICSP and OneView)

    # Check if profile exists first
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
    if matching_profiles['count'] > 0
      profile = matching_profiles['members'].first
      power_on(action_handler, machine_spec, profile['serverHardwareUri']) # Make sure server is started
      return profile
    end

    # Search for OneView Template by name
    templates = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{server_template}'&sort=name:asc")
    unless templates['members'] && templates['members'].count > 0
      fail "Template '#{server_template}' not found! Please match the template name with one that exists on OneView."
    end
    template_uri = templates['members'].first['uri']

    # Get first availabe (and compatible) HP OV server blade
    chosen_blade = available_hardware_for_template(templates['members'].first)

    power_off(action_handler, machine_spec, chosen_blade['uri'])

    # Create new profile instance from template
    action_handler.perform_action "Initialize creation of server profile for #{machine_spec.name}" do
      action_handler.report_progress "INFO: Initializing creation of server profile for #{machine_spec.name}"

      new_template_profile = rest_api(:oneview, :get, "#{template_uri}")

      # Take response, add name & hardware uri, and post back to /rest/server-profiles
      new_template_profile['name'] = host_name
      new_template_profile['uri'] = nil
      new_template_profile['serialNumber'] = nil
      new_template_profile['uuid'] = nil
      new_template_profile['taskUri'] = nil
      new_template_profile['connections'].each do |c|
        c['wwnn'] = nil
        c['wwpn'] = nil
        c['mac']  = nil
      end

      new_template_profile['serverHardwareUri'] = chosen_blade['uri']
      task = rest_api(:oneview, :post, '/rest/server-profiles', { 'body' => new_template_profile })
      task_uri = task['uri']
      # Wait for profile to be applied
      60.times do # Wait for up to 5 min
        matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=name matches '#{host_name}'&sort=name:asc")
        break if matching_profiles['count'] > 0
        print '.'
        sleep 5
      end
      unless matching_profiles['count'] > 0
        task = rest_api(:oneview, :get, task_uri)
        fail "Server profile couldn't be created! #{task['taskStatus']}. #{task['taskErrors'].first['message']}"
      end
    end
    matching_profiles['members'].first
  end
end
