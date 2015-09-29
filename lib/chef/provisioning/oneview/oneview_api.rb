Dir[File.dirname(__FILE__) + '/**/*.rb'].each {|file| require file } # Include all helper files in this directory & subdirectories

module OneViewAPI
  private

  include OneViewAPIv1_2
  include OneViewAPIv2_0

  def get_oneview_api_version
    begin
      version = rest_api(:oneview, :get, '/rest/version', { 'Content-Type' => :none, 'X-API-Version' => :none, 'auth' => :none })['currentVersion']
      fail "Couldn't get API version" unless version
      if version.class != Fixnum
        version = version.to_i
        fail 'API version type mismatch' if !version > 0
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
    fail("\nERROR! Couldn't log into OneView server at #{@oneview_base_url}. Response:\n#{response}")
  end

  def get_oneview_profile_by_sn(serialNumber)
    fail 'Must specify a serialNumber!' if serialNumber.nil? || serialNumber.empty?
    matching_profiles = rest_api(:oneview, :get, "/rest/server-profiles?filter=serialNumber matches '#{serialNumber}'&sort=name:asc")
    fail "Failed to get oneview profile by serialNumber: #{serialNumber}. Response: #{matching_profiles}" unless matching_profiles['count']
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
      fail "'#{template_name}' matches multiple templates! Please use a unique template name." if templates && templates.count > 1
    end

    # Look for Server Profile as second option
    templates = rest_api(:oneview, :get, "/rest/server-profiles?filter=\"name matches '#{template_name}'\"&sort=name:asc")['members']
    return templates.first if templates && templates.count == 1
    fail "'#{template_name}' matches multiple profiles! Please use a unique template name." if templates && templates.count > 1

    fail "Template '#{template_name}' not found! Please match the template name with one that exists on OneView."
  end

  def available_hardware_for_template(template)
    server_hardware_type_uri = template['serverHardwareTypeUri']
    enclosure_group_uri      = template['enclosureGroupUri']
    fail 'Template must specify a valid hardware type uri!' if server_hardware_type_uri.nil? || server_hardware_type_uri.empty?
    fail 'Template must specify a valid hardware type uri!' if enclosure_group_uri.nil? || enclosure_group_uri.empty?
    params = "sort=name:asc&filter=serverHardwareTypeUri='#{server_hardware_type_uri}'&filter=serverGroupUri='#{enclosure_group_uri}'"
    blades = rest_api(:oneview, :get, "/rest/server-hardware?#{params}")
    fail 'Error! No available blades that are compatible with the server template!' unless blades['count'] > 0
    blades['members'].each do |member|
      return member if member['state'] == 'NoProfileApplied'
    end
    fail 'No more blades are available for provisioning!' # Every bay is full and no more machines can be allocated
  end

  def oneview_wait_for(task_uri, wait_iterations = 60, sleep_seconds = 10)
    fail 'Must specify a task_uri!' if task_uri.nil? || task_uri.empty?
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
    else fail "Invalid power state #{state}"
    end

    if hardware_uri.nil?
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
      hardware_uri = profile['serverHardwareUri']
    end

    hardware_info = rest_api(:oneview, :get, hardware_uri)
    unless hardware_info['powerState'].downcase == state
      action_handler.perform_action "Power #{state} server #{hardware_info['name']} for #{machine_spec.name}" do
        action_handler.report_progress "INFO: Powering #{state} server #{hardware_info['name']} for #{machine_spec.name}"
        task = rest_api(:oneview, :put, "#{hardware_uri}/powerState", { 'body' => { 'powerState' => state.capitalize, 'powerControl' => 'MomentaryPress' } })
        task_uri = task['uri']
        60.times do # Wait for up to 10 minutes
          task = rest_api(:oneview, :get, task_uri)
          break if task['taskState'].downcase == 'completed'
          print '.'
          sleep 10
        end
        fail "Powering #{state} machine #{machine_spec.name} failed!" unless task['taskState'].downcase == 'completed'
      end
    end
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
        task = rest_api(:oneview, :Delete, "#{profile['uri']}")
        task_uri = task['uri']

        60.times do # Wait for up to 10 minutes
          task = rest_api(:oneview, :get, task_uri)
          break if task['taskState'].downcase == 'completed'
          print '.'
          sleep 10
        end
        fail "Deleting server profile #{machine_spec.name} failed!" unless task['taskState'].downcase == 'completed'
      end
    end
  end
end
