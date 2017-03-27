require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  let(:profile_120) do
    'spec/support/fixtures/oneview/v120/server_profile_web01_with_san.json'
  end

  describe '#destroy_icsp_server' do
    it 'destroys the server' do
      a = action_handler
      m = machine_spec
      @driver_120.instance_eval { destroy_icsp_server(a, m) }
      expect(a_request(:delete, %r{/rest/os-deployment-servers/.*})).to have_been_made
    end
  end

  describe '#icsp_configure_nic_teams' do
    it 'configures nic teams properly' do
      machine_options = valid_machine_options
      profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_120)
      ret_val = @driver_120.instance_eval { icsp_configure_nic_teams(machine_options, profile) }
      expect(ret_val).to eq('team1-11:11:11:11:01:14,11:11:11:11:01:15')
    end

    it 'requires connection IDs to map to valid OneView connection IDs' do
      machine_options = valid_machine_options
      profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_120)
      machine_options[:driver_options][:connections][99] = { team: 'team2' }
      expect { @driver_120.instance_eval { icsp_configure_nic_teams(machine_options, profile) } }.to raise_error(/make sure the connection ids map to those on OneView/)
    end

    it 'does not allow nic teams with hyphens' do
      machine_options = valid_machine_options
      profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_120)
      machine_options[:driver_options][:connections][1][:team] = 'team-1'
      expect { @driver_120.instance_eval { icsp_configure_nic_teams(machine_options, profile) } }.to raise_error(/must not include hyphens/)
    end

    it 'requires at least 2 connections per team' do
      machine_options = valid_machine_options
      profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_120)
      machine_options[:driver_options][:connections].delete(2)
      expect { @driver_120.instance_eval { icsp_configure_nic_teams(machine_options, profile) } }.to raise_error(/must have at least 2 associated connections/)
    end

  end

end
