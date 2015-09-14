This directory contains everything you need to start provisioning with OneView and Chef.

## Usage with a Chef Server
 1. Create `.chef/<CLIENT_NAME>.pem` and `.chef/oneview-validator.pem` files, and populate them with your client and validator keys for your Chef server org.
 2. Create `.chef/knife.rb` using the `.chef/knife.rb.example` file as a template. Fill it with the correct info for your Chef server. It also contains a data hash for provisioning the oneview machines. You can either fill the data out here, or edit the recipe at `cookbooks/provisioning_cookbook/recipes/default.rb` directly.
 3. Then from this (examples) directory, run: 

```bash
$ chef exec bundle
$ berks install
$ berks upload
$ chef exec bundle exec chef-client -z cookbooks/provisioning_cookbook/recipes/default.rb
```

## Usage with Chef Zero
**NOTE:** This provisioner will provision the node, install the OS, and configure networking, but it **won't** be able to bootstrap the node and apply a runlist. You'll have to bootstrap it as a seperate step. This is because zero will pass a chef_server_url parameter of "chefzero://localhost:8889" to the node at bootstrap time, which the node won't be able to resolve to your machine.
 1. Create `.chef/knife.rb` using the `.chef/knife.rb.example` file as a template. Fill it with the correct info for your OneView and ICSP instances. You don't have to worry about the Chef Server info or the client or validator keys.  This file also contains a data hash for provisioning the oneview machines. You can either fill the data out here, or edit the recipe at `cookbooks/provisioning_cookbook/recipes/zero.rb` directly.
 2. Then from this (examples) directory, run: 
 
  ```bash
  $ chef exec bundle
  $ berks install
  $ berks upload
  $ chef exec bundle exec chef-client -z cookbooks/provisioning_cookbook/recipes/zero.rb
  ```
 
 4. If you want to continue and bootstrap the machine, you'll have two options: (1) set up a Chef Server and bootstrap it like normal or (2) copy the cookbooks onto the node and run chef-client in local (zero) mode from there.

## Troubleshooting

- One of the most common problems people run into is ssl certificate verification issues with private Chef servers. See [ssl_issues.md](ssl_issues.md) to fix these errors.
