require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  describe '#create_machine' do
    include_context 'shared context'

    let(:machine_name) do
      'chef-web01'
    end

    before :each do
      @profile = OneviewSDK::ServerProfile.new(@ov_200, name: 'chef-web01', uri: '/rest/fake',
        serverHardwareTypeUri: '/rest/fake2', enclosureGroupUri: '/rest/fake3')
      @hw = OneviewSDK::ServerHardware.new(@ov_200, name: 'Enclosure-1, bay 1', uri: '/rest/fake4')
    end

    context 'when the profile already exists' do
      it 'skips creating the profile' do
        expect(OneviewSDK::ServerProfile).to receive(:find_by).and_return([@profile])
        expect(@driver_200).to_not receive(:get_oneview_template)
        a = action_handler
        m = machine_name
        o = valid_machine_options
        p = @driver_200.instance_eval { create_machine(a, m, o) }
        expect(p).to eq(@profile)
      end
    end

    context 'when the profile does not exist' do
      it 'creates a new profile' do
        expect(OneviewSDK::ServerProfile).to receive(:find_by).and_return([])
        a = action_handler
        m = machine_name
        o = valid_machine_options
        expect(@driver_200).to receive(:profile_from_template)
          .with(o[:driver_options][:server_template], o[:driver_options][:profile_name]).and_return(@profile)
        expect(@driver_200).to receive(:available_hardware_for_profile)
          .with(@profile, o[:driver_options][:server_location]).and_return(@hw)
        expect(@hw).to receive(:power_off).and_return(true)
        expect(@profile).to receive(:set_server_hardware).with(@hw).and_call_original
        expect(@driver_200).to receive(:update_san_info).and_return(true)
        expect(@ov_200).to receive(:rest_post).and_return(FakeResponse.new({}, 202))
        expect(@profile).to receive(:retrieve!).and_return(true)
        p = @driver_200.instance_eval { create_machine(a, m, o) }
        expect(p[:name]).to eq(o[:driver_options][:profile_name])
        expect(p[:serverHardwareTypeUri]).to eq('/rest/fake2')
        expect(p[:enclosureGroupUri]).to eq('/rest/fake3')
        expect(p[:serverHardwareUri]).to eq('/rest/fake4')
      end

      it 'prints an error message if the creation failed' do
        expect(OneviewSDK::ServerProfile).to receive(:find_by).and_return([])
        a = action_handler
        m = machine_name
        o = valid_machine_options
        expect(@driver_200).to receive(:profile_from_template)
          .with(o[:driver_options][:server_template], o[:driver_options][:profile_name]).and_return(@profile)
        expect(@driver_200).to receive(:available_hardware_for_profile)
          .with(@profile, o[:driver_options][:server_location]).and_return(@hw)
        expect(@hw).to receive(:power_off).and_return(true)
        expect(@profile).to receive(:set_server_hardware).with(@hw).and_call_original
        expect(@driver_200).to receive(:update_san_info).and_return(true)
        expect(@ov_200).to receive(:rest_post).and_return(FakeResponse.new({}, 500))
        expect { @driver_200.instance_eval { create_machine(a, m, o) } }.to raise_error(/Server profile couldn't be created/)
      end
    end

  end
end
