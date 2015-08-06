require 'pry'
require_relative './../lib/chef/provisioning/driver_init/oneview'
#require 'webmock/rspec'
#WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:get_oneview_api_version).and_return("1.20")
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:get_icsp_api_version).and_return("120")
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:login_to_oneview).and_return("long_oneview_key")
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:login_to_icsp).and_return("long_icsp_key")
  end
end

#Chef::Log.level = :debug
Chef::Config[:log_level] = :warn
