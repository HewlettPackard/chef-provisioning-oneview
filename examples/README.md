This directory contains everything you need to start provisioning with OneView and Chef.

## Usage with a Chef Server
 1. Create `.chef/<CLIENT_NAME>.pem` and `.chef/oneview-validator.pem` files, and populate them with your client and validator keys for your Chef server org.
 2. Create `.chef/knife.rb` using the `.chef/knife.rb.example` file as a template. Fill it with the correct info for your Chef server. It also contains a data hash for provisioning the oneview machines. You can either fill the data out here, or edit the recipe at `cookbooks/provisioning_cookbook/recipes/default.rb` directly.
   - Run `$ knife client list` from this (examples) directory to test your configuration.
 3. Make sure the chef-provisioning-oneview gem is installed (see top level readme of this project if you don't know how to do that).
 4. Then from this (examples) directory, run: 

```bash
$ bundle
$ berks install
$ berks upload
$ bundle exec chef-client -z cookbooks/provisioning_cookbook/recipes/default.rb
```

## Usage with Chef Zero
TODO
