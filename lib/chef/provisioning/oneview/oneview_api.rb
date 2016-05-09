Dir[File.dirname(__FILE__) + '/**/*.rb'].each {|file| require file } # Include all helper files in this directory & subdirectories

module OneViewAPI
  private

  include OneViewAPIv1_2
  include OneViewAPIv2_0
  include OneViewSanStorage

  def get_oneview_api_version
    begin
      version = rest_api(:oneview, :get, '/rest/version', { 'Content-Type' => :none, 'X-API-Version' => :none, 'auth' => :none })['currentVersion']
      raise "Couldn't get API version" unless version
      if version.class != Fixnum
        version = version.to_i
        raise 'API version type mismatch' if !version > 0
      end
    rescue
      puts 'Failed to get OneView API version. Setting to default (120)'
      version = 120
    end
    version
  end

  def login_to_oneview
    path = '/rest/login-sessions'
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

  def get_oneview_profile_by_sn(serial_number)
    raise 'Must specify a serialNumber!' if serial_number.nil? || serial_number.empty?
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=serialNumber matches '#{serial_number}'&sort=name:asc")
    raise "Failed to get oneview profile by serialNumber: #{serial_number}. Response: #{matching_profiles}" unless matching_profiles['count']
    return matching_profiles['members'].first if matching_profiles['count'] > 0
    nil
  end

  # Search for OneView Template by name
  def get_oneview_template(template_name)
    if @current_oneview_api_version >= 200
      # Look for Server Profile Template (OneView 2.0 or higher)
      options = { 'X-API-Version' => 200 }
      templates = rest_api(:oneview, :get, "/rest/server-profile-templates?filter=\"name matches '#{template_name}'\"&sort=name:asc", options)['members']
      return rest_api(:oneview, :get, "#{templates.first['uri']}/new-profile", options) if templates && templates.count == 1
      raise "'#{template_name}' matches multiple templates! Please use a unique template name." if templates && templates.count > 1
    end

    # Look for Server Profile as second option
    templates = rest_api(:oneview, :get, "/rest/server-profiles?filter=\"name matches '#{template_name}'\"&sort=name:asc")['members']
    if templates && templates.count == 1
      # Remove unwanted fields
      %w(uri serialNumber uuid taskUri).each {|key| templates.first[key] = nil}
      templates.first['connections'].each do |c|
        %w(wwnn wwpn mac deploymentStatus interconnectUri wwpnType macType).each {|key| c[key] = nil}
      end
      return templates.first
    end
    raise "'#{template_name}' matches multiple profiles! Please use a unique template name." if templates && templates.count > 1

    raise "Template '#{template_name}' not found! Please match the template name with one that exists on OneView."
  end

  def available_hardware_for_template(template)
    server_hardware_type_uri = template['serverHardwareTypeUri']
    enclosure_group_uri      = template['enclosureGroupUri']
    raise 'Template must specify a valid hardware type uri!' if server_hardware_type_uri.nil? || server_hardware_type_uri.empty?
    raise 'Template must specify a valid hardware type uri!' if enclosure_group_uri.nil? || enclosure_group_uri.empty?
    params = "sort=name:asc&filter=serverHardwareTypeUri='#{server_hardware_type_uri}'&filter=serverGroupUri='#{enclosure_group_uri}'"
    blades = rest_api(:oneview, :get, "/rest/server-hardware?#{params}")
    raise 'Error! No available blades that are compatible with the server template!' unless blades['count'] > 0
    blades['members'].each do |member|
      return member if member['state'] == 'NoProfileApplied'
    end
    raise 'No more blades are available for provisioning!' # Every bay is full and no more machines can be allocated
  end

    def hardware_for_template_with_location(template, location)
    server_hardware_type_uri = template['serverHardwareTypeUri']
    enclosure_group_uri      = template['enclosureGroupUri']
    raise 'Template must specify a valid hardware type uri!' if server_hardware_type_uri.nil? || server_hardware_type_uri.empty?
    raise 'Template must specify a valid hardware type uri!' if enclosure_group_uri.nil? || enclosure_group_uri.empty?
    raise 'Location can not be determined' if location.nil? || location.empty?
    params = "sort=name:asc&filter=serverHardwareTypeUri='#{server_hardware_type_uri}'&filter=serverGroupUri='#{enclosure_group_uri}'"
    blades = rest_api(:oneview, :get, "/rest/server-hardware?#{params}")
    raise 'Error! No available blades that are compatible with the server template!' unless blades['count'] > 0
    blades['members'].each do |member|
      return member if member['state'] == 'NoProfileApplied' && member['name'] == location
    end
    raise 'No more blades are available for provisioning!' # Every bay is full and no more machines can be allocated
  end

  

  def oneview_wait_for(task_uri, wait_iterations = 60, sleep_seconds = 10) # Default time is 10 min
    raise 'Must specify a task_uri!' if task_uri.nil? || task_uri.empty?
    wait_iterations.times do
      task = rest_api(:oneview, :get, task_uri)
      case task['taskState'].downcase
      when 'completed'
        return true
      when 'error', 'killed', 'terminated'
        return task
      else
        print '.'
        sleep sleep_seconds
      end
    end
    false
    puts ''
  end

  def wait_for_profile(action_handler, machine_spec,machine_options,  profile)
    unless profile['state'] == 'Normal'
      action_handler.perform_action "Wait for #{machine_spec.name} server to start and profile to be applied" do
        action_handler.report_progress "INFO: Waiting for #{machine_spec.name} server to start and profile to be applied"
        task = oneview_wait_for(profile['taskUri'], 360) # Wait up to 60 min for profile to be created
        raise 'Timed out waiting for server to start and profile to be applied' if task == false
        unless task == true
          server_template = machine_options[:driver_options][:server_template]
          raise "Error creating server profile from template #{server_template}: #{task['taskErrors'].first['message']}"
        end
      end
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number']) # Refresh profile
      raise "Server profile state '#{profile['state']}' not 'Normal'" unless profile['state'] == 'Normal'
    end
    puts ''
  end


  def power_on(action_handler, machine_spec, hardware_uri = nil)
    set_power_state(action_handler, machine_spec, 'on', hardware_uri)
  end

  def power_off(action_handler, machine_spec, hardware_uri = nil)
    set_power_state(action_handler, machine_spec, 'off', hardware_uri)
  end

  def set_power_state(action_handler, machine_spec, state, hardware_uri = nil)
    case state
    when :on, 'on', true
      state = 'on'
    when :off, 'off', false
      state = 'off'
    else raise "Invalid power state #{state}"
    end

    if hardware_uri.nil?
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
      raise "Could not power #{state} #{machine_spec.name}: Profile with serial number '#{machine_spec.reference['serial_number']}' not found!" unless profile
      hardware_uri = profile['serverHardwareUri']
    end

    hardware_info = rest_api(:oneview, :get, hardware_uri)
    unless hardware_info['powerState'].casecmp(state) == 0
      action_handler.perform_action "Power #{state} server #{hardware_info['name']} for #{machine_spec.name}" do
        action_handler.report_progress "INFO: Powering #{state} server #{hardware_info['name']} for #{machine_spec.name}"
        task = rest_api(:oneview, :put, "#{hardware_uri}/powerState", { 'body' => { 'powerState' => state.capitalize, 'powerControl' => 'MomentaryPress' } })
        task_uri = task['uri']
        60.times do # Wait for up to 10 minutes
          task = rest_api(:oneview, :get, task_uri)
          break if task['taskState'].casecmp('completed') == 0
          print '.'
          sleep 10
        end
        raise "Powering #{state} machine #{machine_spec.name} failed!" unless task['taskState'].casecmp('completed') == 0
      end
    end
    puts ''
    hardware_uri
  end

  def destroy_oneview_profile(action_handler, machine_spec, profile = nil)
    profile ||= get_oneview_profile_by_sn(machine_spec.reference['serial_number'])

    hardware_info = rest_api(:oneview, :get, profile['serverHardwareUri'])
    if hardware_info.nil?
      action_handler.report_progress "INFO: #{machine_spec.name} is already deleted."
    else
      action_handler.perform_action "Delete server #{machine_spec.name} from oneview" do
        action_handler.report_progress "INFO: Deleting server profile #{machine_spec.name}"
        task = rest_api(:oneview, :Delete, profile['uri'])
        task_uri = task['uri']

        60.times do # Wait for up to 10 minutes
          task = rest_api(:oneview, :get, task_uri)
          break if task['taskState'].casecmp('completed') == 0
          print '.'
          sleep 10
        end
        raise "Deleting server profile #{machine_spec.name} failed!" unless task['taskState'].casecmp('completed') == 0
      end
    end
  end
end
