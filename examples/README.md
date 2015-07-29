This directory contains everything you need to start provisioning with OneView and Chef.

## Usage with a Chef Server
 1. Create `.chef/<CLIENT_NAME>.pem` and `.chef/oneview-validator.pem` files, and populate them with your client and validator keys for your Chef server org.
 2. Create `.chef/knife.rb` using the `.chef/knife.rb.example` file as a template. Fill it with the correct info for your Chef server.
   - Run `$ knife client list` from this (examples) directory to test your configuration.
 3. Modify `cookbooks/provisioning_cookbook/recipes/default.rb` to fit your infrastructure configuration. Some options such as gateway, dns, ip4_1, and ip4_2 have been split out into the 'Custom Options' section for convenience.
 4. Make sure the chef-provisioning-oneview gem is installed (see top level readme of this project if you don't know how to do that).
 5. Then from this (examples) directory, run: 

```bash
$ bundle
$ berks install
$ berks upload
$ bundle exec chef-client -z cookbooks/provisioning_cookbook/recipes/default.rb
```

## Usage with Chef Zero
TODO
