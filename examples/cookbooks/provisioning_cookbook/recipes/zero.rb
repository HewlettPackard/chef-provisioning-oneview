#
# Cookbook Name:: provisioning_cookbook
# Recipe:: default
#
# Copyright (C) 2015 HP
#
# All rights reserved - Do Not Redistribute
#

knife_options = Chef::Config.knife[:example_recipe_options] || {}

#====================================================
#================== Custom Options ==================
#====================================================
#============ NOTE: Fill this section out ===========

os_build    = knife_options['os_build']    || 'CHEF-RHEL-6.5-x64'
my_template = knife_options['template']    || 'Template - Web Server'
gateway     = knife_options['gateway']     || 'xx.xx.xx.xx'
dns         = knife_options['dns']         || 'xx.xx.xx.xx'
domain_name = knife_options['domain_name'] || 'oneview-domain.com'
mask        = knife_options['mask']        || '255.255.254.0'

# Hash that defines the machines to build. IP is the only attribute right now, but change as necessary.
my_machines = knife_options['my_machines'] || {
  'chef-web01' => {
    'ip4' => 'xx.xx.xx.xx'
  },
  'chef-web02' => {
    'ip4' => 'xx.xx.xx.xx'
  }
}
#====================================================
#================ End Custom Options ================
#====================================================

require 'chef/provisioning'

with_driver 'oneview'

log "Using '#{Chef::Config[:node_name]}' for knife client name"
log "Using '#{Chef::Config[:client_key]}' for knife client key"

machine_batch 'oneview-machine-batch' do
# Note: Enclosing the machine resources in this machine_batch block allows them to provision in parallel.
  
  action :setup # We can only go this far with Chef Zero. You'll have to bootstrap the node seperately.

  my_machines.each do |m_name, options|
    
    machine m_name do

      machine_options :driver_options => {
        :server_template => my_template,
        :os_build => os_build,
        :host_name => m_name,
        :ip_address => options['ip4'], # For bootstrapping only.
        
        :domainType => 'workgroup',
        :domainName => domain_name,
        :gateway =>  gateway,
        :dns => dns,
        :connections => {
          #1 => { ... } (Reserved for PXE)
          2 => {
            :ip4Address => options['ip4'],
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
      converge false
    end # End machine resource block
    
  end # End my_machines.each loop

end # End machine_batch resource block
