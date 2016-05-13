RSpec.shared_context 'shared context', a: :b do

  domain = 'my-domain.com'
  chef_server = "https://my-chef-server.#{domain}/organizations/oneview"
  oneview = "https://my-oneview.#{domain}"
  icsp = "https://my-icsp.#{domain}"

  let(:knife_config) do
    { knife: {
      oneview_url: oneview,
      oneview_username: 'Administrator',
      oneview_password: 'password12',
      oneview_ignore_ssl: true,
      oneview_timeout: 15,

      icsp_url: icsp,
      icsp_username: 'administrator',
      icsp_password: 'password123'
    } }
  end

  let(:valid_machine_options) do
    {
      convergence_options: {
        ssl_verify_mode: :verify_none,
        bootstrap_proxy: "http://proxy.#{domain}:8080",
        chef_server: {
          chef_server_url: chef_server,
          options: {
            client_name: 'user',
            signing_key_filename: 'spec/fixtures/.chef/user.pem'
          }
        }
      },
      driver_options: {
        server_template: 'Template - Web Server',
        os_build: 'CHEF-RHEL-6.5-x64',
        host_name: 'chef-web01',
        ip_address: '192.168.1.2',
        domainType: 'workgroup',
        domainName: domain,
        gateway: '192.168.1.1',
        dns: '192.168.1.1,10.1.1.1',
        connections: {
          1 => { dhcp: true, team: 'team1' },
          2 => { ip4Address: '192.168.1.2', mask: '255.255.254.0', dhcp: false, team: 'team1' }
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
    ChefProvisioningOneviewHelpers::FakeActionHandler.new
  end

  let(:machine_spec) do
    ChefProvisioningOneviewHelpers::FakeMachineSpec.new('server-1', 'VCGE9KB041')
  end

  let(:machine_spec2) do
    ChefProvisioningOneviewHelpers::FakeMachineSpec.new('server-2', '789123')
  end

  before :each do
    @oneview_key = 'A954A2A6Psy7Alg3HApAcEbAcAwa-ftA'
    @icsp_key = 'AA_aaAaa3AA3Aa0_aAaAA4AAAA3AAAAA'
    @url = oneview
    @canonical_url = "oneview:#{@url}"
    @instance = Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config)
  end

end
