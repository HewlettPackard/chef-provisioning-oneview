require 'pry'
require 'webmock/rspec'
require 'simplecov'
SimpleCov.start

require_relative './../lib/chef/provisioning/driver_init/oneview'
require_relative 'support/fake_response'
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

    @oneview_url = 'https://oneview.example.com'
    @oneview_user = 'Administrator'
    @oneview_password = 'secret123'
    @oneview_token = 'A954A2A6Psy7Alg3HApAcEbAcAwa-ftA'

    @icsp_url = 'https://icsp.example.com'
    @icsp_user = 'admin'
    @icsp_password = 'secret456'
    @icsp_key = 'AA_aaAaa3AA3Aa0_aAaAA4AAAA3AAAAA'

    @canonical_url = "oneview:#{@oneview_url}"

    stub_request(:any, /icsp.example.com/).to_rack(FakeIcsp)

    allow_any_instance_of(OneviewSDK::Client).to receive(:appliance_api_version).and_return(200)
    allow_any_instance_of(OneviewSDK::Client).to receive(:login).and_return(@oneview_token)
    allow(OneviewSDK::SSLHelper).to receive(:load_trusted_certs).and_return(nil)

    # Clear environment variables
    %w(ONEVIEWSDK_URL ONEVIEWSDK_USER ONEVIEWSDK_PASSWORD ONEVIEWSDK_TOKEN ONEVIEWSDK_SSL_ENABLED).each do |name|
      ENV[name] = nil
    end
  end

end

# Chef::Log.level = :debug
Chef::Config[:log_level] = :warn
