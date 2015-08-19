require_relative './../spec_helper'
require_relative 'support/fake_action_handler'

RSpec.describe Chef::Provisioning::OneViewDriver do
  let(:knife_config) do
    { knife: {
      oneview_url: 'https://my-oneview.my-domain.com',
      oneview_username: 'Administrator',
      oneview_password: 'password12',
      oneview_ignore_ssl: true,

      icsp_url: 'https://my-icsp.my-domain.com',
      icsp_username: 'administrator',
      icsp_password: 'password123'
    } }
  end

  let(:valid_machine_options) do
    {
      convergence_options: {
        ssl_verify_mode: :verify_none,
        bootstrap_proxy: 'http://proxy.my-domain.com:8080',
        chef_server: {
          chef_server_url: 'https://my-chef-server.my-domain.com/organizations/oneview',
          options: {
            client_name: 'user',
            signing_key_filename: 'spec/fixtures/.chef/user.pem'
          }
        }
      },
      driver_options: {
        server_template: 'Template - Web Server',
        os_build: 'CHEF-RHEL-6.5-x64',
        host_name: 'chef-web03',
        ip_address: '192.168.1.2',
        domainType: 'workgroup',
        domainName: 'my-domain.com',
        gateway: '192.168.1.1',
        dns: '192.168.1.1,10.1.1.1',
        connections: {
          2 => { ip4Address: '192.168.1.2', mask: '255.255.254.0', dhcp: false }
        }
      },
      custom_attributes: {

      },
      transport_options: {
        ssh_options: { password: 'password1234' }
      }
    }
  end

  let(:action_handler) do
    @handler ||= ChefProvisioningOneviewHelpers::FakeActionHandler.new
  end

  let(:machine_spec) do
    # TODO
  end

  describe '#canonicalize_url' do
    it 'canonicalizes the url' do
      url = 'https://oneview.domain.com'
      config = {}
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url("oneview:#{url}", config)).to eq("oneview:#{url}")
    end

    it 'canonicalizes the url from the config' do
      url = 'https://oneview.domain.com'
      config = { knife: { oneview_url: url } }
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url('oneview:', config)).to eq("oneview:#{url}")
    end
  end

  describe '#initialize' do
    before :each do
      @url = 'https://oneview.domain.com'
      canonical_url = "oneview:#{@url}"
      @instance = Chef::Provisioning::OneViewDriver.new(canonical_url, knife_config)
    end

    it 'reads all necessary values from knife config during initialization' do
      expect(@instance.instance_variable_get('@oneview_base_url')).to eq('https://my-oneview.my-domain.com')
      expect(@instance.instance_variable_get('@oneview_username')).to eq('Administrator')
      expect(@instance.instance_variable_get('@oneview_password')).to eq('password12')
      expect(@instance.instance_variable_get('@oneview_disable_ssl')).to eq(true)
      expect(@instance.instance_variable_get('@oneview_api_version')).to eq(120)
      expect(@instance.instance_variable_get('@oneview_key')).to eq('long_oneview_key')

      expect(@instance.instance_variable_get('@icsp_base_url')).to eq('https://my-icsp.my-domain.com')
      expect(@instance.instance_variable_get('@icsp_username')).to eq('administrator')
      expect(@instance.instance_variable_get('@icsp_password')).to eq('password123')
      expect(@instance.instance_variable_get('@icsp_disable_ssl')).to eq(nil)
      expect(@instance.instance_variable_get('@icsp_api_version')).to eq(102)
      expect(@instance.instance_variable_get('@icsp_key')).to eq('long_icsp_key')
    end
  end
end
