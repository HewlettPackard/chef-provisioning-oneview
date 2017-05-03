# chef-provisioning-oneview

Chef Provisioning driver for HPE OneView

[![Build Status](https://travis-ci.org/HewlettPackard/chef-provisioning-oneview.svg?branch=master)](https://travis-ci.org/HewlettPackard/chef-provisioning-oneview)
[![Gem Version](https://badge.fury.io/rb/chef-provisioning-oneview.svg)](https://badge.fury.io/rb/chef-provisioning-oneview)

Questions or comments? Join the Gitter room  [![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/HewlettPackard/chef-provisioning-oneview?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Verified on (may support other versions too, but no guarantees):
- OneView v1.2.0 - 2.0.0
- ICsp v7.4.0 - 7.5.0

:warning: This driver does not support provisioning with HPE Synergy Image Streamer. It is recommended to use the [HPE OneView Chef cookbook](https://github.com/HewlettPackard/oneview-chef) if you are trying to do it.

# Installation

- This program is meant to run inside the chef-client. To install it, add the following to a Chef recipe and run it:

  ```ruby
  chef_gem 'chef-provisioning-oneview'
  ```


# Credentials & Configuration

There are a few different ways to provide credentials and configuration for this driver.

- In a recipe using the `with_driver` method:
  
  ```ruby
  # The basic usage is:
  # with_driver canonical_url, driver_options
  
  with_driver 'oneview:https://oneview.example.com', {
    oneview: {
      url: 'https://oneview2.example.com' # Will be overridden by the canonical url above
      user: 'Administrator',
      password: 'secret123',
      token: 'token123', # Optional. Use EITHER this or the username & password
      ssl_enabled: true, # Optional. Defaults to true
      timeout: 10 # Optional. In seconds
    },
    icsp: {
      url: 'https://icsp.example.com'
      user: 'Admin',
      password: 'secret456',
      ssl_enabled: true, # Optional. Defaults to true
      timeout: 20 # Optional. In seconds
    }
  }
  ```

- You can also use the following options in your `knife.rb` file:
  
  ```ruby
  # (knife.rb)
  # (in addition to all the normal stuff like node_name, client_key, validation_client_name, validation_key, chef_server_url, etc.)
  knife[:oneview_url]        = 'https://oneview.example.com'
  knife[:oneview_username]   = 'Administrator'
  knife[:oneview_password]   = 'password123'
  knife[:oneview_token]      = 'token123' # Use EITHER this or the username & password
  knife[:oneview_ignore_ssl] = true # For self-signed certs (discouraged)
  knife[:oneview_timeout]    = 10 # Optional. In seconds
  
  knife[:icsp_url]           = 'https://icsp.example.com'
  knife[:icsp_username]      = 'Administrator'
  knife[:icsp_password]      = 'password123'
  knife[:icsp_ignore_ssl]    = true # For self-signed certs (discouraged)
  knife[:icsp_timeout]       = 20 # Optional. In seconds
  
  knife[:node_root_password] = 'password123'
  
  # If your Chef server has self-signed certs:
  verify_api_cert              false
  ssl_verify_mode              :verify_none
  ```

- Finally, there are a few environment variables that you can set:
  
  ```bash
  export ONEVIEWSDK_USER='Administrator'
  export ONEVIEWSDK_PASSWORD='secret123'
  export ONEVIEWSDK_TOKEN='token123'
  ```

Since there are a few diferent ways of providing the same config values, here's the order of evaluation:
  - **OneView URL:** canonical_url (ie `oneview:https://oneview.example.com`), driver_options[:oneview][:url], knife[:oneview_url], ENV['ONEVIEWSDK_URL']
  - **OneView user, password, & token:** driver_options, knife, environment variable
  - **ICSP url, user, & password:** driver_options, knife

Note: ICSP is not required, so if you don't want to use it, you can leave out those config options and it will be ignored.

### Additional Setup

- Your OneView, Insight Controll Server Provisioning(ICSP), and Chef server must be trusted by your certificate stores. See [examples/ssl_issues.md](examples/ssl_issues.md) for more info on how to do this.
  - You can also use the OneView SDK cli tool to import your OneView cert. See [this](https://github.com/HewlettPackard/oneview-sdk-ruby#cli).
- Your OneView and ICSP servers must be set up beforehand. Unfortunately, this driver doesn't do that for you too.

# Usage

Example recipe:
```ruby
require 'chef/provisioning'

with_driver 'oneview:https://oneview.example.com', {
  oneview: { user: 'Administrator', password: 'secret123' },
  icsp: { url: 'https://icsp.example.com' user: 'Admin', password: 'secret456' }
}

machine 'web01' do
  recipe 'my_server_cookbook::default'

  machine_options driver_options: {
      server_template: 'Web Server Template', # Name of Template OR Server Profile
      os_build: 'CHEF-RHEL-6.5-x64', # Name of OS Build Plan on ICSP. Supports array of strings also.
      server_location: 'Encl1, bay 16', # Optional. Use to provision a specific server
      
      host_name: 'chef-web01',
      ip_address: 'xx.xx.xx.xx', # For bootstrapping. Deprecated in favor of { bootstrap: true } in connection; see below
      domainType: 'workgroup',
      domainName: 'sub.domain.com',
      mask: '255.255.255.0', # Can set here or in individual connections below
      dhcp: false, # Can set here or in individual connections below
      gateway:  'xx.xx.xx.1', # Can set here or in individual connections below
      dns: 'xx.xx.xx.xx,xx.xx.xx.xx,xx.xx.xx.xx', # Can set here or in individual connections below
      connections: {
        #1 => { ... } (Reserved for PXE on our setup)
        2 => {
          ip4Address: 'xx.xx.xx.xx',
          mask: '255.255.254.0', # Optional. Overrides mask property above
          dhcp: false            # Optional. Overrides dhcp property above
          gateway: 'xx.xx.xx.1'  # Optional. Overrides gateway property above
          dns: 'xx.xx.xx.xx'     # Optional. Overrides dns property above
          bootstrap: true        # Set this on 1 connection only. Tells Chef which connection to use to bootstrap.
        },
        3 => {
          dhcp: true             # Optional. Overrides dhcp property above
          gateway: :none         # Optional. Overrides gateway property above
          dns: :none             # Optional. Overrides dns property above
        }
      },
      skip_network_configuration: false, # Default. Set to true for EXSi hosts, etc.
      custom_attributes: {
        chefCert: 'ssh-rsa AA...' # Optional
      }
    },
    transport_options: {
      user: 'root', # Optional. Defaults to 'root'
      ssh_options: {
        password: Chef::Config.knife[:node_root_password]
      }
    },
    convergence_options: {
      ssl_verify_mode: :verify_none, # Optional. For Chef servers with self-signed certs
      bootstrap_proxy: 'http://proxy.example.com:8080' # Optional
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
custom_attributes: {
  chefCert: 'ssh-rsa AA...'
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
transport_options: {
  ssh_options: {
    auth_methods: ['publickey'],
    keys: ['~/.ssh/id_rsa']
  }
}
```

You'll also need to put the corresponding public key(s) into the node's authorized_keys file during the OS setup. See the Custom Attributes section above for one way to do this.

### Behind a proxy

Add `bootstrap_proxy: 'http://proxy.example.com:8080'` to your convergence_options hash.
Also, make sure your OS build plans set up the proxy configuration in a post OS install script.

### SAN Storage

In order to attach a SAN volume as a bootable volume, the volume name must start with 'boot'; it will be appended with the the profile name on creation.

### Switching to a different network after provisioning

Add `1 => {net: "Deadnetwork", deployNet: "PXE Network", dhcp: true}` to your connections hash. 
This will flip the first connection of the newly provisioned machine off of your pxe network to your Deadnetwork right after provisioning. This is helpful for taking the newly provisioned machine off the PXE network as soon as possible. 

### Adding Nic Teams

Add `team: 'TeamName'` into a connection in your connections hash. Make sure that you have 2 connections in a team and the name does not include hyphens. This information will be passed to ISCP as the 'teams' custom attribute in the format: `"TeamName1-mac1,mac2|TeamName2-mac6,mac7,mac8"` to be consumed in a custom build plan script.

# Doing a test run

This repo contains everything you need to get started, including example recipes and knife configuration files. See the README in the [examples](examples/) directory for how to begin provisioning.


# Troubleshooting

See the [Trouleshooting wiki page](https://github.com/HewlettPackard/chef-provisioning-oneview/wiki/Troubleshooting)


# Contributing

You know the drill. Fork it, branch it, change it, commit it, pull-request it. We're passionate about improving this driver, and glad to accept help to make it better.

### Building the Gem

To build this gem, run `$ rake build` or `gem build chef-provisioning-oneview.gemspec`.

Then once it's built you can install it by running `$ rake install` or `$ gem install ./chef-provisioning-oneview-<VERSION>.gem`.

Note: You may need to first install the `ruby-devel` or `ruby-dev` package for your system.

### Testing

- RuboCop: `$ rake rubocop` or `$ rubocop .`
- Rspec: `$ rake spec` or `$ rspec`
- Both: Run `$ rake test` to run both RuboCop and Rspec tests.

# Authors

 - Jared Smartt - [@jsmartt](https://github.com/jsmartt)
 - Matthew Frahry - [@mbfrahry](https://github.com/mbfrahry)
 - Andy Claiborne - [@veloandy](https://github.com/veloandy)
 - Gunjan Kamle - [@kgunjan](https://github.com/kgunjan)
