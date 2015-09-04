module ICspAPI
  private

  def get_icsp_api_version
    begin
      version = rest_api(:icsp, :get, '/rest/version', { 'Content-Type' => :none, 'X-API-Version' => :none, 'auth' => :none })['currentVersion']
      fail "Couldn't get API version" unless version
      if version.class != Fixnum
        version = version.to_i
        fail 'API version type mismatch' if !version > 0
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
    fail("\nERROR! Couldn't log into OneView server at #{@oneview_base_url}. Response:\n#{response}")
  end

  def get_icsp_server_by_sn(serialNumber)
    fail 'Must specify a serialNumber!' if serialNumber.nil? || serialNumber.empty?
    search_result = rest_api(:icsp, :get,
      "/rest/index/resources?category=osdserver&query='osdServerSerialNumber:\"#{serialNumber}\"'")['members'] rescue nil
    if search_result && search_result.size == 1 && search_result.first['attributes']['osdServerSerialNumber'] == serialNumber
      my_server_uri = search_result.first['uri']
      my_server = rest_api(:icsp, :get, my_server_uri)
    end
    unless my_server && my_server['uri']
      os_deployment_servers = rest_api(:icsp, :get, '/rest/os-deployment-servers')
      # Pick the relevant os deployment server from icsp
      my_server = nil
      os_deployment_servers['members'].each do |server|
        if server['serialNumber'] == serialNumber
          my_server = server
          break
        end
      end
    end
    my_server
  end

  def icsp_wait_for(task_uri, wait_iterations = 60, sleep_seconds = 10)
    fail 'Must specify a task_uri!' if task_uri.nil? || task_uri.empty?
    wait_iterations.times do
      task = rest_api(:icsp, :get, task_uri)
      if task['taskState']
        case task['taskState'].downcase
        when 'completed'
          return true
        when 'error', 'killed', 'terminated'
          return task
        end
      elsif task['running'] == 'false'
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

  def destroy_icsp_server(action_handler, machine_spec)
    my_server = get_icsp_server_by_sn(machine_spec.reference['serial_number'])
    return false if my_server.nil? || my_server['uri'].nil?

    action_handler.perform_action "Delete server #{machine_spec.name} from ICSP" do
      task = rest_api(:icsp, :delete, my_server['uri']) # TODO: This returns nil instead of task info

      if task['uri']
        task_uri = task['uri']
        90.times do # Wait for up to 15 minutes
          task = rest_api(:icsp, :get, task_uri)
          break if task['taskState'].downcase == 'completed'
          print '.'
          sleep 10
        end
        fail "Deleting os deployment server #{machine_spec.name} at icsp failed!" unless task['taskState'].downcase == 'completed'
      end
    end
  end
end # End module
