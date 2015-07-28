#
# Cookbook Name:: provisioning_cookbook
# Recipe:: default
#
# Copyright (C) 2015 HP
#
# All rights reserved - Do Not Redistribute
#

require 'chef/provisioning'

with_driver 'oneview'

with_chef_server Chef::Config.knife[:my_chef_server],
  :client_name => Chef::Config[:node_name],
  :signing_key_filename => Chef::Config[:client_key]

log "Using '#{Chef::Config[:node_name]}' for knife client name"
log "Using '#{Chef::Config[:client_key]}' for knife client key"


# ===========================================================================================================
enabled_nodes = []
# Note: to make it easier to enable/disable nodes, simply comment or uncomment the following:
enabled_nodes.push 'chef-web01'
enabled_nodes.push 'chef-web02'
# ===========================================================================================================

# Custom Options:
os_build = 'CHEF-RHEL-6.5-x64'
gateway = '192.168.0.1'
dns = 'xx.xx.xx.xx'
domain_name = 'oneview-domain.com'
mask = '255.255.254.0'
ip4_1 = 'xx.xx.xx.xx' # IP of chef-web01
ip4_2 = 'xx.xx.xx.xx' # IP of chef-web02


machine_batch do
  #action :converge # Options are :converge , :stop , or :destroy   (among others, but those are the main ones)

  machine 'chef-web01' do
    recipe 'my_apache_server'

    machine_options :driver_options => {
      :server_template => 'Web Server Template',
      :os_build => os_build,
      :host_name => 'chef-web01',
      :ip_address => ip4_1, # For bootstrapping only.
      
      :domainType => 'workgroup',
      :domainName => domain_name,
      :gateway =>  gateway,
      :dns => dns,
      :connections => {
        #1 => { ... } (Reserved for PXE)
        2 => {
          :ip4Address => ip4_1,
          :mask => mask,
          :dhcp => false
        }
      }
    },
    :custom_attributes => {},
    :transport_options => {
      :ssh_options => {
        :password => Chef::Config.knife[:node_root_password]
      }
    },
    :convergence_options => {
      :ssl_verify_mode => :verify_none,
      :bootstrap_proxy => Chef::Config.knife[:bootstrap_proxy]
    }

    chef_environment '_default'
    converge true
  end

  machine 'chef-web02' do
    recipe 'my_apache_server'

    machine_options :driver_options => {
      :server_template => 'Web Server Template',
      :os_build => os_build,
      :host_name => 'chef-web02',
      :ip_address => ip4_2, # For bootstrapping only.
      
      :domainType => 'workgroup',
      :domainName => domain_name,
      :gateway =>  gateway,
      :dns => dns,
      :connections => {
        #1 => { ... } (Reserved for PXE)
        2 => {
          :ip4Address => ip4_2,
          :mask => mask,
          :dhcp => false
        }
      }
    },
    :custom_attributes => {},
    :transport_options => {
      :ssh_options => {
        :password => Chef::Config.knife[:node_root_password]
      }
    },
    :convergence_options => {
      :ssl_verify_mode => :verify_none,
      :bootstrap_proxy => Chef::Config.knife[:bootstrap_proxy]
    }

    chef_environment '_default'
    converge true
  end

end
