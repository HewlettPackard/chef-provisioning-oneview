require 'chef/json_compat'
require 'chef/knife'
require 'chef/provisioning'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/driver'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/machine/unix_machine'
require 'json'
require 'oneview-sdk'
require_relative 'driver_init/oneview'
require_relative 'version'
require_relative 'helpers'

module Chef::Provisioning
  # Provisioning driver for HPE OneView
  class OneViewDriver < Chef::Provisioning::Driver
    include OneviewChefProvisioningDriver::Helpers

    def self.canonicalize_url(url, config)
      _scheme, oneview_url = url.split(':', 2)
      oneview_url ||= config[:driver_options][:oneview][:url] rescue nil
      oneview_url ||= config[:knife][:oneview_url] rescue nil
      oneview_url ||= ENV['ONEVIEWSDK_URL']
      raise 'Must set the oneview driver url! See docs for more info' if oneview_url.nil? || oneview_url.empty?
      "oneview:#{oneview_url}"
    end

    def self.from_url(url, config)
      OneViewDriver.new(url, config)
    end

    def initialize(url, config)
      _scheme, oneview_url = url.split(':', 2)
      super(url, config)

      ov_config = config[:driver_options][:oneview] || {} rescue {}
      ov_config = Hash[ov_config.map { |k, v| [k.to_sym, v] }] # Convert string keys to symbols

      ov_config[:url] = oneview_url
      ov_config[:user] ||= config[:knife][:oneview_username] || ENV['ONEVIEWSDK_USER']
      ov_config[:password] ||= config[:knife][:oneview_password] || ENV['ONEVIEWSDK_PASSWORD']
      ov_config[:token] ||= config[:knife][:oneview_token] || ENV['ONEVIEWSDK_TOKEN']
      ov_config[:ssl_enabled] = false if ov_config[:ssl_enabled] == false || (ov_config[:ssl_enabled].nil? && config[:knife][:oneview_ignore_ssl])
      ov_config[:timeout] ||= config[:knife][:oneview_timeout] if config[:knife][:oneview_timeout]
      ov_config[:print_wait_dots] = true if ov_config[:print_wait_dots].nil?
      ov_config[:logger] = Chef::Log
      @ov = OneviewSDK::Client.new(ov_config) # OneView client object

      icsp_config = config[:driver_options][:icsp] || {} rescue {}

      @icsp_base_url       = icsp_config[:url] || config[:knife][:icsp_url]
      @icsp_username       = icsp_config[:user] || config[:knife][:icsp_username]
      @icsp_password       = icsp_config[:password] || config[:knife][:icsp_password]
      @icsp_disable_ssl    = false
      @icsp_disable_ssl    = true if icsp_config[:ssl_enabled] == false || config[:knife][:icsp_ignore_ssl] == true
      @icsp_api_version    = 102 # Use this version for all calls that don't override it
      @icsp_timeout        = icsp_config[:timeout] || config[:knife][:icsp_timeout]

      Chef::Log.warn 'ICSP url not set! ICSP will be ignored'      if @icsp_base_url.nil?
      Chef::Log.warn 'ICSP user not set! ICSP will be ignored'     if @icsp_username.nil?
      Chef::Log.warn 'ICSP password not set! ICSP will be ignored' if @icsp_password.nil?

      @icsp_ignore = @icsp_base_url.nil? || @icsp_username.nil? || @icsp_password.nil?
      # If the config is not specified, skip ICSP
      return if @icsp_ignore
      Chef::Log.debug("Logging into ICSP at #{@icsp_base_url}")
      @current_icsp_api_version = get_icsp_api_version
      @icsp_key = login_to_icsp
    end


    def allocate_machine(action_handler, machine_spec, machine_options)
      raise 'Machine definition missing :driver_options parameter!' unless machine_options[:driver_options]
      if machine_spec.reference
        profile = OneviewSDK::ServerProfile.find_by(@ov, serialNumber: machine_spec.reference['serial_number']).first
        if profile # Update reference data
          machine_spec.reference['driver_url'] = driver_url
          machine_spec.reference['driver_version'] = ONEVIEW_DRIVER_VERSION
          # TODO: Update profile if differs from Chef and/or Template config
          machine_spec.reference['profile_name'] = profile['name']
        else # It doesn't really exist
          action_handler.report_progress "Machine #{machine_spec.name} does not really exist.  Recreating ..."
          machine_spec.reference = nil
        end
      end
      unless machine_spec.reference
        action_handler.perform_action "Allocate server #{machine_spec.name}" do
          profile = create_machine(action_handler, machine_spec.name, machine_options)
          machine_spec.reference = {
            'driver_url' => driver_url,
            'driver_version' => ONEVIEW_DRIVER_VERSION,
            'serial_number' => profile['serialNumber'],
            'profile_name' => profile['name']
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
      profile = OneviewSDK::ServerProfile.find_by(@ov, serialNumber: machine_spec.reference['serial_number']).first
      raise "Failed to retrieve Server Profile for #{machine_spec.name}. Serial Number used to search: #{machine_spec.reference['serial_number']}" unless profile
      customize_machine(action_handler, machine_spec, machine_options, profile)
      if @icsp_ignore == true
        Chef::Log.warn("Skipping ICSP configuration for machine '#{machine_spec.name}'")
        Machine::BasicMachine.new(machine_spec, OneViewNilTransport.new, OneViewNilConvergence.new)
      else # Return a machine object that Chef can connect to (to install chef-client)
        machine_for(machine_spec, machine_options)
      end
    end


    def machine_for(machine_spec, machine_options)
      bootstrap_ip_address = ip_from_machine(machine_spec, machine_options)
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
        machine_options[:convergence_options], {}
      )
      Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport, convergence_strategy)
    end

    def stop_machine(_action_handler, machine_spec, _machine_options)
      return unless machine_spec.reference
      profile = OneviewSDK::ServerProfile.find_by(@ov, serialNumber: machine_spec.reference['serial_number']).first
      profile.get_server_hardware.power_off
    end


    def destroy_machine(action_handler, machine_spec, machine_options)
      return unless machine_spec.reference
      profile = OneviewSDK::ServerProfile.find_by(@ov, serialNumber: machine_spec.reference['serial_number']).first
      if profile
        profile.get_server_hardware.power_off
        action_handler.perform_action "Delete server profile #{machine_spec.name}" do
          action_handler.report_progress "INFO: Deleting server profile #{machine_spec.name}"
          profile.delete
        end
      else
        action_handler.report_progress "INFO: #{machine_spec.name} is already deleted."
      end
      destroy_icsp_server(action_handler, machine_spec) unless @icsp_ignore # Delete os deployment server from ICSP

      name = machine_spec.name # Save for next steps

      # Remove entry from known_hosts file(s)
      ip_address = ip_from_machine(machine_spec, machine_options)
      return unless ip_address
      action_handler.perform_action "Delete entries for #{name} (#{ip_address}) from known_hosts file(s)" do
        files = [File.expand_path('~/.ssh/known_hosts'), File.expand_path('/etc/ssh/known_hosts')]
        files.each do |f|
          next unless File.exist?(f)
          begin
            text = File.read(f)
            text.gsub!(/#{ip_address} ssh-rsa.*(\n|\r\n)/, '')
            File.open(f, 'w') { |file| file.puts text } if text
          rescue Exception => e
            action_handler.report_progress "WARN: Failed to delete entries for #{name} (#{ip_address}) from known_hosts file: '#{f}'! "
            puts "Error: #{e.message}"
          end
        end
      end
    end # destroy_machine method end


    def connect_to_machine(machine_spec, machine_options)
      machine_for(machine_spec, machine_options)
    end

    private

    def ip_from_machine(machine_spec, machine_options)
      return machine_options[:driver_options][:ip_address] if machine_options[:driver_options][:ip_address]

      id, connection = machine_options[:driver_options][:connections].find { |_id, c| c[:bootstrap] == true }
      raise 'Must specify a connection to use to bootstrap!' unless id && connection # TODO: Try first connection anyways?
      return connection[:ip4Address] if connection[:ip4Address] # Return static IP if set
      # Look for dhcp address given to this connection
      if machine_spec.data['normal']['icsp'] && machine_spec.data['normal']['icsp']['interfaces']
        interface = machine_spec.data['normal']['icsp']['interfaces'].find { |i| i['oneViewId'] == id }
        if interface
          addr = interface['ipv4Addr'] || interface['ipv6Addr']
          return addr if addr
        end
      end
      profile = OneviewSDK::ServerProfile.find_by(@ov, serialNumber: machine_spec.reference['serial_number']).first
      my_server = get_icsp_server_by_sn(machine_spec.reference['serial_number'])
      mac = profile['connections'].find { |x| x['id'] == id }['mac']
      interface = my_server['interfaces'].find { |i| i['macAddr'] == mac }
      addr = interface['ipv4Addr'] || interface['ipv6Addr']
      addr ||= my_server['hostName'] # Fall back on hostName
      Chef::Log.warn "IP address for '#{machine_spec.name}' not specified and could not be retrieved!" unless addr
      addr
    end

  end # class end

  # Additional No-Op classes to nil return when a :converge is called
  # Returns a OneViewTransport::disconnect (nil)
  class OneViewNilTransport
    def disconnect(*_args, &_block)
      nil
    end
  end

  # Additional Converge class that nils the called methods under a :converge action
  class OneViewNilConvergence
    def setup_convergence(*_args, &_block)
      nil
    end

    def converge(*_args, &_block)
      nil
    end
  end
end # module end
