# chef-provisioning-oneview
Chef Provisioning driver for HP OneView


[![Build Status](https://travis-ci.org/HewlettPackard/chef-provisioning-oneview.svg?branch=master)](https://travis-ci.org/HewlettPackard/chef-provisioning-oneview)
[![Gem Version](https://badge.fury.io/rb/chef-provisioning-oneview.svg)](https://badge.fury.io/rb/chef-provisioning-oneview)

Questions or comments? Join the Gitter room  [![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/HewlettPackard/chef-provisioning-oneview?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)


Currently supports:
- OneView v1.2.0 - 2.0.0
- ICsp v7.4.0 - 7.5.0

# Installation

- Install Ruby and the `ruby-devel` or `ruby-dev` package for your system.
  
- Require the gem in your Gemfile: `gem 'chef-provisioning-oneview'`
  
  Then run `$ bundle install`
- Or run the command:
  
  ```ruby
  $ gem install chef-provisioning-oneview
  ```



# Prerequisites
- Set up your `knife.rb` file with the information the driver needs to connect to OneView and Insight Control Server Provisioning
  
  ```ruby
  # (knife.rb)
  # (in addition to all the normal stuff like node_name, client_key, validation_client_name, validation_key, chef_server_url, etc.)
  knife[:oneview_url]        = 'https://my-oneview.my-domain.com'
  knife[:oneview_username]   = 'Administrator'
  knife[:oneview_password]   = 'password123'
  knife[:oneview_ignore_ssl] = true # For self-signed certs
  
  knife[:icsp_url]           = 'https://my-icsp.my-domain.com'
  knife[:icsp_username]      = 'Administrator'
  knife[:icsp_password]      = 'password123'
  knife[:icsp_ignore_ssl]    = true # For self-signed certs
  
  knife[:node_root_password] = 'password123'
  
  # If your Chef server has self-signed certs:
  verify_api_cert              false
  ssl_verify_mode              :verify_none
  ```

- Your OneView, Insight Controll Server Provisioning(ICSP), and Chef server must be trusted by your certificate stores. See [examples/ssl_issues.md](examples/ssl_issues.md) for more info on how to do this.
- Your OneView and ICSP servers must be set up beforehand. Unfortunately, this driver doesn't do that for you too.

# Usage

Example recipe:
```ruby
require 'chef/provisioning'

with_driver 'oneview'

with_chef_server "https://my-chef.my-domain.com/organizations/my-org",
  :client_name => Chef::Config[:node_name],          # NOTE: This must have node & client creation privileges (ie admin group)
  :signing_key_filename => Chef::Config[:client_key] # NOTE: This must have node & client creation privileges (ie admin group)

machine 'web01' do
  recipe 'my_server_cookbook::default'

  machine_options :driver_options => {
      :server_template => 'Web Server Template',
      :os_build => 'CHEF-RHEL-6.5-x64',
      :host_name => 'chef-web01',
      :ip_address => 'xx.xx.xx.xx', # For bootstrapping. Deprecated in favor of { bootstrap: true } in connection; see below
      
      :domainType => 'workgroup',
      :domainName => 'sub.domain.com',
      :mask => '255.255.255.0', # Can set here or in individual connections below
      :dhcp => false,
      :gateway =>  'xx.xx.xx.1',
      :dns => 'xx.xx.xx.xx,xx.xx.xx.xx,xx.xx.xx.xx',
      :connections => {
        #1 => { ... } (Reserved for PXE on our setup)
        2 => {
          :ip4Address => 'xx.xx.xx.xx',
          :mask => '255.255.254.0', # Optional. Overrides mask property above
          :dhcp => false            # Optional. Overrides dhcp property above
          :gateway => 'xx.xx.xx.1'  # Optional. Overrides gateway property above
          :dns => 'xx.xx.xx.xx'     # Optional. Overrides dns property above
          :bootstrap => true        # Set this on 1 connection only. Tells Chef which connection to use to bootstrap.
        },
        3 => {
          :dhcp => true             # Optional. Overrides dhcp property above
          :gateway => :none         # Optional. Overrides gateway property above
          :dns => :none             # Optional. Overrides dns property above
        }
      },
      :skip_network_configuration => false, # Default. Set to true for EXSi hosts, etc.
      :custom_attributes => {
        :chefCert => 'ssh-rsa AA...' # Optional
      }
    },
    :transport_options => {
      :user => 'root', # Optional. Defaults to 'root'
      :ssh_options => {
        :password => Chef::Config.knife[:node_root_password]
      }
    },
    :convergence_options => {
      :ssl_verify_mode => :verify_none, # Optional. For Chef servers with self-signed certs
      :bootstrap_proxy => 'http://proxy.domain.com:8080' # Optional
    }

  chef_environment '_default'
  converge true
end
```

See https://github.com/chef/chef-provisioning-ssh for more transport_options.

NOTE: Some basic connection settings such as :ip4Address and :dhcp are shown in the example recipe, but you can pass in any interface/nic options that exist in the ICsp api for POST requests to /rest/os-deployment-jobs

### Custom Attributes
Insided the custom attributes hash, you can specify any data that you would like to pass into your ICsp build plan scripts or configuration files. For example, to specify a list of trusted public keys to be placed into the node's .ssh/authorized_keys file, add a custom attribute to the machine resource definition:

```ruby
:custom_attributes => {
  :chefCert => 'ssh-rsa AA...'
}
```

Then create/modify a custom build script in ICsp that will do something with this data. To access it, use the format: `@variable_name@` or `@variable_name:default_value@`. For our example, we could do something like:

```bash
#!/bin/bash
authorized_keys = @chefCert@
if [ -n "$authorized_keys"]; then
  echo -e "$authorized_keys" > /mnt/sysimage/root/.ssh/authorized_keys
fi
```

### SSH Keys
To use SSH keys insead of passwords to connect to nodes, you'll need to modify your transport_options to look something like:

```ruby
:transport_options => {
  :ssh_options => {
    :auth_methods => ['publickey'],
    :keys => ['~/.ssh/id_rsa']
  }
}
```

You'll also need to put the corresponding public key(s) into the node's authorized_keys file during the OS setup. See the Custom Attributes section above for one way to do this.

### Behind a proxy
Add `:bootstrap_proxy => 'http://proxy.domain.com:8080'` to your convergence_options hash.
Also, make sure your OS build plans set up the proxy configuration in a post OS install script.

### SAN Storage
In order to attach a SAN volume as a bootable volume, the volume name must start with 'boot'; it will be appended with the the profile name on creation.

### Switching to a different network after provisioning
Add `1 => {:net => "Deadnetwork", :deployNet => "PXE Network", :dhcp => true}` to your connections hash. 
This will flip the first connection of the newly provisioned machine off of your pxe network to your Deadnetwork right after provisioning. This is helpful for taking the newly provisioned machine off the PXE network as soon as possible. 

### Adding Nic Teams
Add `:team => 'TeamName'` into a connection in your connections hash. Make sure that you have 2 connections in a team and the name does not include hyphens. This information will be passed to ISCP as the 'teams' custom attribute in the format: `"TeamName1-mac1,mac2|TeamName2-mac6,mac7,mac8"` to be consumed in a custom build plan script.

# Doing a test run
This repo contains everything you need to get started, including example recipes and knife configuration files. See the README in the [examples](examples/) directory for how to begin provisioning.


# Contributing
You know the drill. Fork it, branch it, change it, commit it, pull-request it. We're passionate about improving this driver, and glad to accept help to make it better.

### Building the Gem
To build this gem, run `$ rake build` or `gem build chef-provisioning-oneview.gemspec`.

Then once it's built you can install it by running `$ rake install` or `$ gem install ./chef-provisioning-oneview-<VERSION>.gem`.

### Testing
- RuboCop: `$ rake rubocop` or `$ rubocop .`
- Rspec: `$ rake spec` or `$ rspec`
- Both: Run `$ rake test` to run both RuboCop and Rspec tests.

# Authors
 - Jared Smartt - [@jsmartt](https://github.com/jsmartt)
 - Gunjan Kamle - [@kgunjan](https://github.com/kgunjan)
 - Matthew Frahry - [@mbfrahry](https://github.com/mbfrahry)
 - Andy Claiborne - [@veloandy](https://github.com/veloandy)
