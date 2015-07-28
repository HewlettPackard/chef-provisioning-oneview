# See http://docs.chef.io/config_rb_knife.html for more information on knife configuration options
current_dir = File.dirname(__FILE__)

#=============================================================================
# Edit these attributes:
my_chef_server_url         = "https://chef-server.domain.com/organizations/oneview"

node_name                    "CLIENT_NAME"
validation_client_name       "oneview-validator"

knife[:oneview_site]       = 'https://my-oneview.my-domain.com'
knife[:oneview_username]   = 'Administrator'
knife[:oneview_password]   = 'password123'
knife[:oneview_ignore_ssl] = true

knife[:icsp_site]          = 'https://my-icsp.my-domain.com'
knife[:icsp_username]      = 'Administrator'
knife[:icsp_password]      = 'password123'
knife[:icsp_ignore_ssl]    = true

knife[:node_root_password] = 'password123'

# For self-signed Chef server cert
verify_api_cert              false
ssl_verify_mode              :verify_none

# If you're behind a proxy
my_proxy = 'http://proxy.domain.com:8080'
#=============================================================================






log_level                :info
log_location             STDOUT
client_key               "#{current_dir}/client.pem"
validation_key           "#{current_dir}/validator.pem"
cache_type               'BasicFile'
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["#{current_dir}/../cookbooks"]
chef_server_url          my_chef_server_url
knife[:my_chef_server] = my_chef_server_url
if my_proxy
  http_proxy             my_proxy
  https_proxy            my_proxy
  bootstrap_proxy        my_proxy
end
