require 'pry'
require_relative './../lib/chef/provisioning/driver_init/oneview'
require_relative 'support/fake_oneview'
require_relative 'support/fake_icsp'
require 'webmock/rspec'
# WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before(:each) do
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:get_oneview_api_version).and_return('1.20')
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:get_icsp_api_version).and_return('120')
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:login_to_oneview).and_return('long_oneview_key')
    allow_any_instance_of(Chef::Provisioning::OneViewDriver).to receive(:login_to_icsp).and_return('long_icsp_key')

    stub_request(:any, /my-oneview.my-domain.com/).to_rack(FakeOneView)
    stub_request(:any, /my-icsp.my-domain.com/).to_rack(FakeIcsp)
  end
end

# Chef::Log.level = :debug
Chef::Config[:log_level] = :warn
