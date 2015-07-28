This directory contains everything you need to start provisioning with OneView and Chef.

## Usage with a Chef Server
 1. Modify the `.chef/knife.rb`, `.chef/client.pem, and `.chef/validator.pem` files with the correct info for your Chef server and user.
   - Run `$ knife client list` from **this** directory to test your configuration.
 2. Modify `cookbooks/provisioning_cookbook/recipes/default.rb` to fit your infrastructure configuration. Some options such as gateway, dns, ip4_1, and ip4_2 have been split out into the 'Custom Options' section for convenience.
 3. Make sure the chef-provisioning-oneview gem is installed (see top level readme of this project if you don't know how to do that).
 4. Then from **this** directory, run: 

```bash
$ bundle
$ berks install
$ berks upload
$ bundle exec chef-client -z cookbooks/provisioning_cookbook/recipes/default.rb
```

## Usage with Chef Zero
TODO
