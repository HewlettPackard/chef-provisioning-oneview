require 'chef/json_compat'
require 'chef/knife'
require 'chef/provisioning'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/driver'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/machine/unix_machine'
require 'json'
require 'ridley'
require_relative 'driver_init/oneview'
require_relative 'version'
require_relative 'rest'
require_relative 'create_machine'
require_relative 'customize_machine'
require_relative 'oneview/oneview_api'
require_relative 'icsp/icsp_api'

module Chef::Provisioning
  class OneViewDriver < Chef::Provisioning::Driver
    include CreateMachine
    include CustomizeMachine
    include RestAPI
    include OneViewAPI
    include ICspAPI


    # Additional No-Op classes to nil return when a :converge is called
    # Returns a OneViewTransport::disconnect (nil)
    class OneViewTransport
     def disconnect(*args, &block)
      nil
     end
    end

   # Additional Converge class that nils the called methods under a :converge action
    class OneViewConvergence
     def setup_convergence(*args, &block)
      nil
     end
     def converge(*args, &block)
      nil
     end
    end




    def self.canonicalize_url(url, config)
      _scheme, oneview_url = url.split(':', 2)
      if oneview_url.nil? || oneview_url == ''
        oneview_url = config[:knife][:oneview_url]
      end
      raise 'Must set the knife[:oneview_url] attribute!' if oneview_url.nil? || oneview_url.empty?
      'oneview:' + oneview_url
    end

    def self.from_url(oneview_url, config)
      OneViewDriver.new(oneview_url, config)
    end

    def initialize(canonical_url, config)
      super(canonical_url, config)

      @oneview_base_url    = config[:knife][:oneview_url]
      raise 'Must set the knife[:oneview_url] attribute!' if @oneview_base_url.nil? || @oneview_base_url.empty?
      @oneview_username    = config[:knife][:oneview_username]
      raise 'Must set the knife[:oneview_username] attribute!' if @oneview_username.nil? || @oneview_username.empty?
      @oneview_password    = config[:knife][:oneview_password]
      raise 'Must set the knife[:oneview_password] attribute!' if @oneview_password.nil? || @oneview_password.empty?
      @oneview_disable_ssl = config[:knife][:oneview_ignore_ssl]
      @oneview_api_version = 120 # Use this version for all calls that don't override it
      @api_timeout = 5 # default timeout
      @api_timeout = config[:knife][:api_timeout] #get the timeout from the knife.rb config
      @current_oneview_api_version = get_oneview_api_version
      @oneview_key         = login_to_oneview

      @icsp_base_url       = config[:knife][:icsp_url]
      #puts 'WARNING: Haven\'t set the knife[:icsp_url] in knife.rb!' if @icsp_base_url.nil? || @icsp_base_url.empty?
      @icsp_username       = config[:knife][:icsp_username]
      #puts 'WARNING: Haven\'t set the knife[:icsp_username] in knife.rb!' if @icsp_username.nil? || @icsp_username.empty?
      @icsp_password       = config[:knife][:icsp_password]
      #puts 'WARNING: Haven\'t set the knife[:icsp_password] in knife.rb!' if @icsp_password.nil? || @icsp_password.empty?
      @icsp_disable_ssl    = config[:knife][:icsp_ignore_ssl]
      @icsp_api_version    = 102 # Use this version for all calls that don't override it

      # Added newline to make reading of output easier
      puts ''
      @icsp_ignore = false
      # Additional Checks to see if there is an ICSP server specified
      if @icsp_base_url.nil?
	Chef::Log.warn("WARNING: Haven\'t set the knife[:icsp_url] in knife.rb!")
        @icsp_ignore = true
      end
      
      if @icsp_username.nil?
        Chef::Log.warn("WARNING: Haven\'t set the knife[:icsp_username] in knife.rb!")
        @icsp_ignore = true
      end
      
      if @icsp_password.nil?
        Chef::Log.warn("WARNING: Haven\'t set the knife[:icsp_password] in knife.rb!")
        @icsp_ignore = true 
      end
      
      if @icsp_ignore == false
	    Chef::Log.info("ICSP configuration complete, logging into ICSP") 
            @current_icsp_api_version = get_icsp_api_version
            @icsp_key            = login_to_icsp
      end
      
   
   end


    def allocate_machine(action_handler, machine_spec, machine_options)
      host_name = machine_options[:driver_options][:host_name]
      if machine_spec.reference
        if get_oneview_profile_by_sn(machine_spec.reference['serial_number']).nil? # It doesn't really exist
          action_handler.report_progress "Machine #{host_name} does not really exist.  Recreating ..."
          machine_spec.reference = nil
        else # Update reference data
          machine_spec.reference['driver_url'] = driver_url
          machine_spec.reference['driver_version'] = ONEVIEW_DRIVER_VERSION
        end
      end
      if !machine_spec.reference
        action_handler.perform_action "Creating server #{machine_spec.name}" do
          profile = create_machine(action_handler, machine_spec, machine_options)
          machine_spec.reference = {
            'driver_url' => driver_url,
            'driver_version' => ONEVIEW_DRIVER_VERSION,
            'serial_number' => profile['serialNumber']
          }
        end
      end
    end


    def allocate_machines(action_handler, specs_and_options, _parallelizer)
      specs_and_options.each do |machine_spec, machine_options|
        allocate_machine(action_handler, machine_spec, machine_options)
      end
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
      raise "Failed to retrieve Server Profile for #{machine_spec.name}. Serial Number used to search: #{machine_spec.reference['serial_number']}" unless profile
      if @icsp_key.nil?
        wait_for_profile(action_handler, machine_spec, machine_options, profile)
        Chef::Log.warn " WARNING: Converge action being used"
        transport = OneViewTransport.new
        convergence = OneViewConvergence.new
        Machine::BasicMachine.new(machine_spec, transport, convergence)
      else
        # This function takes care of installing the operating system etc. to the machine (blade)
        customize_machine(action_handler, machine_spec, machine_options, profile)
           #This is a provisining function and handles installing a chef-client
        machine_for(machine_spec, machine_options) # Return the Machine object 
     end
    end


    def machine_for(machine_spec, machine_options)
        bootstrap_ip_address = machine_options[:driver_options][:ip_address]
        unless bootstrap_ip_address
          id, connection = machine_options[:driver_options][:connections].find { |_id, c| c[:bootstrap] == true }
          raise 'Must specify a connection to use to bootstrap!' unless id && connection
          bootstrap_ip_address = connection[:ip4Address] # For static IPs
          unless bootstrap_ip_address # Look for dhcp address given to this connection
            profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
            my_server = get_icsp_server_by_sn(machine_spec.reference['serial_number'])
            mac = profile['connections'].find {|x| x['id'] == id}['mac']
            interface = my_server['interfaces'].find { |i| i['macAddr'] == mac }
            bootstrap_ip_address = interface['ipv4Addr'] || interface['ipv6Addr']
          end
          bootstrap_ip_address ||= my_server['hostName'] # Fall back on hostName
        end
        raise 'Server IP address not specified and could not be retrieved!' unless bootstrap_ip_address
        username = machine_options[:transport_options][:user] || 'root' rescue 'root'
        default_ssh_options = {
          # auth_methods: ['password', 'publickey'],
          # keys: ['~/.ssh/id_rsa'],
          password: Chef::Config.knife[:node_root_password]
        }
        ssh_options = machine_options[:transport_options][:ssh_options] || default_ssh_options rescue default_ssh_options
        default_options = {
          prefix: 'sudo ',
          ssh_pty_enable: true
        }
        options = machine_options[:transport_options][:options] || default_options rescue default_options

        transport = Chef::Provisioning::Transport::SSH.new(bootstrap_ip_address, username, ssh_options, options, config)
        convergence_strategy = Chef::Provisioning::ConvergenceStrategy::InstallSh.new(
          machine_options[:convergence_options], {})
      Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport, convergence_strategy)
  end


    def stop_machine(action_handler, machine_spec, _machine_options)
      power_off(action_handler, machine_spec) if machine_spec.reference
    end


    def destroy_machine(action_handler, machine_spec, machine_options)
      if machine_spec.reference
        power_off(action_handler, machine_spec) # Power off server
        if @icsp_key.nil?
	   puts ''
	   Chef::Log.warn "Not deleting a profile from ICSP"
        else
           destroy_icsp_server(action_handler, machine_spec) # Delete os deployment server from ICSP
        end
        destroy_oneview_profile(action_handler, machine_spec) # Delete server profile from OneView

        name = machine_spec.name # Save for next steps

        # Delete the node from the Chef server
        action_handler.perform_action "Release machine #{machine_spec.reference['serial_number']}" do
          machine_spec.reference = nil
          machine_spec.delete(action_handler)
        end

        # Delete client from the Chef server
        action_handler.perform_action "Delete client '#{name}' from Chef server" do
          begin
            #Ridely::Logging.logger.level = Logger.const_get 'ERROR'
            ridley = Ridley.new(
              server_url:  machine_options[:convergence_options][:chef_server][:chef_server_url],
              client_name: machine_options[:convergence_options][:chef_server][:options][:client_name],
              client_key:  machine_options[:convergence_options][:chef_server][:options][:signing_key_filename]
            )
            ridley.client.delete(name)
          rescue  Exception => e
            action_handler.report_progress "WARN: Failed to delete client #{name} from server!"
            puts "Error: #{e.message}"
          end
        end

        # Remove entry from known_hosts file(s)
        if machine_options[:driver_options][:ip_address]
          action_handler.perform_action "Delete entry for '#{machine_options[:driver_options][:ip_address]}' from known_hosts file(s)" do
            files = [File.expand_path('~/.ssh/known_hosts'), File.expand_path('/etc/ssh/known_hosts')]
            files.each do |f|
              next if !File.exist?(f)
              begin
                text = File.read(f)
                text.gsub!(/#{machine_options[:driver_options][:ip_address]} ssh-rsa.*(\n|\r\n)/, '')
                File.open(f, 'w') {|file| file.puts text } if text
              rescue  Exception => e
                action_handler.report_progress "WARN: Failed to delete entry for '#{machine_options[:driver_options][:ip_address]}' from known_hosts file: '#{f}'! "
                puts "Error: #{e.message}"
              end
            end
          end
        end

      end # End if machine_spec.reference
    end # destroy_machine method end


    def connect_to_machine(machine_spec, machine_options)
      machine_for(machine_spec, machine_options)
    end

    private

    # Login to both OneView and ICsp
    def auth_tokens
      if @icsp_key.nil? 
	puts ''
	Chef::Log.warn "ICSP isn't being used to provisiong OS"
      else
        @icsp_key  ||= login_to_icsp
      end
      @oneview_key ||= login_to_oneview
      { 'icsp_key' => @icsp_key, 'oneview_key' => @oneview_key }
    end

  end # class end
end # module end
