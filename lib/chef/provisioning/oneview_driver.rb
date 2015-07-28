require 'chef/json_compat'
require 'chef/knife'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/driver'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/machine/unix_machine'
require 'json'
require 'ridley'
require_relative 'oneview/oneview_api'

module Chef::Provisioning
  class OneViewDriver < Chef::Provisioning::Driver
    include OneViewAPI

    def self.canonicalize_url(url, config)
      scheme, oneview_url = url.split(':' , 2)
      if oneview_url.nil? || oneview_url == ''
        oneview_url = config[:knife][:oneview_site]
      end
      "oneview:" + oneview_url
    end

    def self.from_url(oneview_url, config)
      OneViewDriver.new(oneview_url, config)
    end

    def initialize(canonical_url, config)
      super(canonical_url, config)

      @oneview_base_url = oneview_url
      @oneview_username = Chef::Config.knife[:oneview_username]
      @oneview_password = Chef::Config.knife[:oneview_password]
      @oneview_disable_ssl = Chef::Config::knife[:oneview_ignore_ssl]
      @oneview_api_version = get_oneview_api_version
      @oneview_key = login_to_oneview

      @icsp_base_url = icsp_url
      @icsp_username = Chef::Config.knife[:icsp_username]
      @icsp_password = Chef::Config.knife[:icsp_password]
      @icsp_disable_ssl = Chef::Config::knife[:icsp_ignore_ssl]
      @icsp_api_version = get_icsp_api_version
      @icsp_key = login_to_icsp
    end

    def oneview_url
      Chef::Config.knife[:oneview_site]
    end

    def icsp_url
      Chef::Config.knife[:icsp_site]
    end


    def allocate_machine(action_handler, machine_spec, machine_options)
      host_name = machine_options[:driver_options][:host_name]
      if machine_spec.reference
        if get_oneview_profile_by_sn(machine_spec.reference['serial_number']).nil? # It doesn't really exist
          action_handler.report_progress "Machine #{host_name} does not really exist.  Recreating ..."
          machine_spec.reference = nil
        end
      end
      if !machine_spec.reference
        action_handler.perform_action "Creating server #{machine_spec.name} with options #{machine_options}" do
          profile = create_machine(action_handler, machine_spec, machine_options)
          machine_spec.reference = {
            'driver_url' => driver_url,
            'driver_version' => ONEVIEW_DRIVER_VERSION,
            'serial_number' => profile['serialNumber']
          }
        end
      end
    end


    def allocate_machines(action_handler, specs_and_options, parallelizer)
      specs_and_options.each do |machine_spec, machine_options|
        allocate_machine(action_handler, machine_spec, machine_options)
      end
    end


    def ready_machine(action_handler, machine_spec, machine_options)
      profile = get_oneview_profile_by_sn(machine_spec.reference['serial_number'])
      my_server = customize_machine(action_handler, machine_spec, machine_options, profile)

      machine_for(machine_spec, machine_options) # Return the Machine object
    end


    def machine_for(machine_spec, machine_options, instance = nil)
      bootstrap_ip_address = machine_options[:driver_options][:ip_address]
      username = machine_options[:transport_options][:user] || 'root' rescue 'root'
      default_ssh_options = {
        #:auth_methods => ['publickey'],
        #:keys => ['/home/username/.vagrant.d/insecure_private_key'],
        :password => Chef::Config.knife[:node_root_password]
      }
      ssh_options = machine_options[:transport_options][:ssh_options] || default_ssh_options rescue default_ssh_options
      default_options = {
        :prefix => 'sudo ',
        :ssh_pty_enable => true
      }
      options = machine_options[:transport_options][:options] || default_options rescue default_options

      transport = Chef::Provisioning::Transport::SSH.new(bootstrap_ip_address, username, ssh_options, options, config)
      convergence_strategy = Chef::Provisioning::ConvergenceStrategy::InstallSh.new(
          machine_options[:convergence_options], {})
      Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport, convergence_strategy)
    end


    def stop_machine(action_handler, machine_spec, machine_options)
      if machine_spec.reference
        power_off(action_handler, machine_spec, machine_options)
      end
    end


    def destroy_machine(action_handler, machine_spec, machine_options)
      if machine_spec.reference
        power_off(action_handler, machine_spec, machine_options) # Power off server
        destroy_icsp_server(action_handler, machine_spec) # Delete os deployment server from ICSP
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
                File.open(f, "w") {|file| file.puts text } if text
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

  end # class end
end # module end
