require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#icsp_configure_nic_teams' do

    it 'configures nic teams properly' do
      machine_options = valid_machine_options
      profile = @instance.instance_eval { get_oneview_profile_by_sn('VCGE9KB041') }
      ret_val = @instance.instance_eval { icsp_configure_nic_teams(machine_options, profile) }
      expect(ret_val).to eq('team1-11:11:11:11:01:14,11:11:11:11:01:15')
    end

    it 'requires connection IDs to map to valid OneView connection IDs' do
      machine_options = valid_machine_options
      profile = @instance.instance_eval { get_oneview_profile_by_sn('VCGE9KB041') }
      machine_options[:driver_options][:connections][3] = { team: 'team2' }
      expect { @instance.instance_eval { icsp_configure_nic_teams(machine_options, profile) } }.to raise_error(/make sure the connection ids map to those on OneView/)
    end

    it 'does not allow nic teams with hyphens' do
      machine_options = valid_machine_options
      profile = @instance.instance_eval { get_oneview_profile_by_sn('VCGE9KB041') }
      machine_options[:driver_options][:connections][1][:team] = 'team-1'
      expect { @instance.instance_eval { icsp_configure_nic_teams(machine_options, profile) } }.to raise_error(/must not include hyphens/)
    end

    it 'requires at least 2 connections per team' do
      machine_options = valid_machine_options
      profile = @instance.instance_eval { get_oneview_profile_by_sn('VCGE9KB041') }
      machine_options[:driver_options][:connections].delete(2)
      expect { @instance.instance_eval { icsp_configure_nic_teams(machine_options, profile) } }.to raise_error(/must have at least 2 associated connections/)
    end

  end

end
