This directory contains everything you need to start provisioning with OneView and Chef.

## Usage with a Chef Server
 **Requirements:** ChefDK installed on your workstation.
 
 1. Create `.chef/<CLIENT_NAME>.pem` and `.chef/oneview-validator.pem` files, and populate them with your client and validator keys for your Chef server org.
 2. Create `.chef/knife.rb` using the `.chef/knife.rb.example` file as a template. Fill it with the correct info for your Chef server. It also contains a data hash for provisioning the oneview machines. You can either fill the data out here, or advanced users may edit the recipe at `cookbooks/provisioning_cookbook/recipes/default.rb` directly.
 3. Then from this (examples) directory, run: 
  
  ```bash
  # Upload the cookbooks to your Chef server using berkshelf:
  $ berks install
  $ berks upload
  
  # Install chef-provisioning-oneview as a Chef gem:
  $ chef-client -z -o provisioning_cookbook::install_gems
  
  # Run the provisioning cookbook:
  $ chef-client -z -o provisioning_cookbook
  ```

## Usage with Chef Zero
**Requirements:** chef-client or ChefDK installed on your workstation.

**NOTE:** This provisioner will provision the node, install the OS, and configure networking, but it **won't** be able to bootstrap the node and apply a runlist. You'll have to bootstrap it as a seperate step. This is because zero will pass a chef_server_url parameter of "chefzero://localhost:8889" to the node at bootstrap time, which the node won't be able to resolve to your machine.
 1. Create `.chef/knife.rb` using the `.chef/knife.rb.example` file as a template. Fill it with the correct info for your OneView and ICSP instances. You don't have to worry about the Chef Server info or the client or validator keys.  This file also contains a data hash for provisioning the oneview machines. You can either fill the data out here, or advanced users may edit the recipe at `cookbooks/provisioning_cookbook/recipes/zero.rb` directly.
 2. Then from this (examples) directory, run: 
  
  ```bash
  # Install chef-provisioning-oneview as a Chef gem:
  $ chef-client -z -o provisioning_cookbook::install_gems
  
  # Run the provisioning cookbook:
  $ chef-client -z -o provisioning_cookbook::zero
  ```
 
 4. If you want to continue and bootstrap the machine, you'll have two options: (1) set up a Chef Server and bootstrap it like normal or (2) copy the cookbooks onto the node and run chef-client in local (zero) mode from there.
 
## Building a Docker container with OneView provisioning and ChefDK
The `examples\Docker\` contains a `Dockerfile` that can be used to build a container with the latest components that can be used to automate HPE OneView with Chef. To build the container the Dockerfile will need copying to a docker host then the `$ docker build` command can be used to pull all the requirements and build the container.

Build Example:

`$ docker build -t OneView-Chef -f <path_to_Dockerfile>`

This container can then be run using the `$ docker run OneView-Chef` command. Further documentation can be found at https://hub.docker.com/r/thebsdbox/oneview-chef/ for passing recipes and configuration into the docker container.

## Troubleshooting

- One of the most common problems people run into is ssl certificate verification issues with private Chef servers. See [ssl_issues.md](ssl_issues.md) to fix these errors.

- Also see the [Trouleshooting wiki page](https://github.com/HewlettPackard/chef-provisioning-oneview/wiki/Troubleshooting)
