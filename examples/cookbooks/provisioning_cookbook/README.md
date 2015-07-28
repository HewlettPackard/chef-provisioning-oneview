# provisioning_cookbook-cookbook
Example cookbook showing how easy it is to provision with OneView and Chef.

## Supported Platforms
TODO

## Attributes

TODO

## Usage
TODO

### provisioning_cookbook::default
Run `$ bundle exec chef-client -z recipes/default.rb` or...   


Include `provisioning_cookbook` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[provisioning_cookbook::default]"
  ]
}
```

## License and Authors
Author:: Jared Smartt (jsmartt)
