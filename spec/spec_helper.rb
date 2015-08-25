require 'pry'
require 'webmock/rspec'
require 'simplecov'
SimpleCov.start

require_relative './../lib/chef/provisioning/driver_init/oneview'
require_relative 'support/fake_oneview'
require_relative 'support/fake_icsp'
require_relative 'support/fake_machine_spec'
require_relative 'support/fake_action_handler'
require_relative 'shared_context'
# WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    stub_request(:any, /my-oneview.my-domain.com/).to_rack(FakeOneView)
    stub_request(:any, /my-icsp.my-domain.com/).to_rack(FakeIcsp)
  end

end

# Chef::Log.level = :debug
Chef::Config[:log_level] = :warn
