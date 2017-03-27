require_relative './../spec_helper'

RSpec.describe OneviewChefProvisioningDriver::OneViewHelper do
  include_context 'shared context'

  let(:helper) do
    (Class.new { include OneviewChefProvisioningDriver::OneViewHelper }).new
  end

  let(:template_name) do
    'Web Server Template'
  end

  let(:profile_name) do
    'chef-web01'
  end

  let(:profile_data) do
    {
      name: template_name,
      uri: '/rest/fake2',
      connections: [
        {
          'id' => 1,
          'name' => 'net1',
          'functionType' => 'Ethernet',
          'deploymentStatus' => 'Deployed',
          'networkUri' => '/rest/ethernet-networks/fake',
          'portId' => 'Flb 1:1-a',
          'requestedVFs' => 'Auto',
          'allocatedVFs' => nil,
          'interconnectUri' => '/rest/interconnects/fake',
          'macType' => 'Virtual',
          'wwpnType' => 'Virtual',
          'mac' => 'CA:1D:00:00:00:00',
          'wwnn' => nil,
          'wwpn' => nil,
          'requestedMbps' => '2500',
          'allocatedMbps' => 2500,
          'maximumMbps' => 10_000,
          'boot' => {
            'priority' => 'Primary',
            'targets' => [{ 'arrayWwpn' => '20000002AC0008DA', 'lun' => '0' }]
          }
        }
      ],
      serialNumber: 'fakesn',
      uuid: 'fakeuuid',
      taskUri: '/rest/fake3',
      enclosureBay: 4,
      enclosureUri: '/rest/fake4'
    }
  end

  describe '#profile_from_template' do
    it 'requires a template_name' do
      expect { helper.profile_from_template(nil, profile_name) }.to raise_error(/Template name missing/)
    end

    before :each do
      @profile = OneviewSDK::ServerProfile.new(@ov_200, profile_data)
    end

    context 'OneView 2.0' do
      before :each do
        @template = OneviewSDK::ServerProfileTemplate.new(@ov_200, name: template_name, uri: '/rest/fake')
        @new_profile = OneviewSDK::ServerProfile.new(@ov_200, name: profile_name, serverProfileTemplateUri: '/rest/fake')
      end

      it 'looks for a ServerProfileTemplate first' do
        t = template_name
        p = profile_name
        expect(OneviewSDK::ServerProfileTemplate).to receive(:find_by).with(@ov_200, name: t).and_return([@template])
        expect(@template).to receive(:new_profile).with(p).and_return(@new_profile)
        p = @driver_200.instance_eval { profile_from_template(t, p) }
        expect(p['name']).to eq(profile_name)
        expect(p['uri']).to be_nil
        expect(p['serverProfileTemplateUri']).to eq(@template['uri'])
      end

      it 'also looks for a ServerProfile' do
        t = template_name
        p = profile_name
        expect(OneviewSDK::ServerProfileTemplate).to receive(:find_by).and_return []
        expect(OneviewSDK::ServerProfile).to receive(:find_by).with(@ov_200, name: t).and_return([@profile])
        p = @driver_200.instance_eval { profile_from_template(t, p) }
        expect(p['name']).to eq(profile_name)
      end

      it 'clears out certain attributes from server profiles' do
        t = template_name
        p = profile_name
        expect(OneviewSDK::ServerProfileTemplate).to receive(:find_by).and_return []
        expect(OneviewSDK::ServerProfile).to receive(:find_by).with(@ov_200, name: t).and_return([@profile])
        p = @driver_200.instance_eval { profile_from_template(t, p) }
        %w(uri serialNumber uuid taskUri enclosureBay enclosureUri).each do |key|
          expect(p[key]).to be_nil
        end
        %w(wwnn wwpn mac deploymentStatus interconnectUri wwpnType macType).each do |key|
          expect(p['connections'].first[key]).to be_nil
        end
      end
    end

    context 'OneView 1.2' do
      it 'does not check for a ServerProfileTemplate' do
        t = template_name
        p = profile_name
        expect(OneviewSDK::ServerProfileTemplate).to_not receive(:find_by)
        expect(OneviewSDK::ServerProfile).to receive(:find_by).with(@ov_120, name: t).and_return([@profile])
        p = @driver_120.instance_eval { profile_from_template(t, p) }
        expect(p['name']).to eq(profile_name)
      end
    end
  end

  describe '#available_hardware_for_profile' do
    before :each do
      @profile = OneviewSDK::ServerProfile.new(@ov_200, serverHardwareTypeUri: '/rest/fake', enclosureGroupUri: '/rest/fake2')
      @hw = OneviewSDK::ServerHardware.new(@ov_200, name: 'Enclosure-1, bay 1', uri: '/rest/fake3')
      @hw2 = OneviewSDK::ServerHardware.new(@ov_200, name: 'Enclosure-1, bay 2', uri: '/rest/fake4')
    end

    it 'requires the serverHardwareTypeUri to be set' do
      p = OneviewSDK::ServerProfile.new(@ov_200, enclosureGroupUri: '/rest/fake2')
      expect { helper.available_hardware_for_profile(p) }.to raise_error(OneviewSDK::IncompleteResource, /Must set/)
    end

    it 'requires the enclosureGroupUri to be set' do
      p = OneviewSDK::ServerProfile.new(@ov_200, serverHardwareTypeUri: '/rest/fake')
      expect { helper.available_hardware_for_profile(p) }.to raise_error(OneviewSDK::IncompleteResource, /Must set/)
    end

    it 'raises an error if there is no available (matching) hardware' do
      expect(@profile).to receive(:get_available_hardware).and_return []
      expect { helper.available_hardware_for_profile(@profile) }.to raise_error(/No available blades/)
    end

    it 'returns the first available (matching) hardware if no location is specified' do
      expect(@profile).to receive(:get_available_hardware).and_return [@hw, @hw2]
      hw = helper.available_hardware_for_profile(@profile)
      expect(hw).to eq(@hw)
    end

    it 'returns the matching hardware if a location is specified' do
      expect(@profile).to receive(:get_available_hardware).and_return [@hw, @hw2]
      hw = helper.available_hardware_for_profile(@profile, 'Enclosure-1, bay 2')
      expect(hw).to eq(@hw2)
    end

    it 'raises an error if a location is specified but that hardware is not available' do
      expect(@profile).to receive(:get_available_hardware).and_return [@hw]
      expect { helper.available_hardware_for_profile(@profile, 'Enclosure-1, bay 2') }.to raise_error(/doesn't exist or doesn't match/)
    end
  end

  describe '#wait_for_profile' do
    it 'returns immediately if the profile state is Normal' do
      profile = OneviewSDK::ServerProfile.new(@ov_200, state: 'Normal')
      res = helper.wait_for_profile(action_handler, machine_spec.name, profile)
      expect(res).to be true
    end

    it 'waits for the profile task if the profile state is not Normal' do
      a = action_handler
      n = machine_spec.name
      profile = OneviewSDK::ServerProfile.new(@ov_200, taskUri: '/rest/fake')
      expect(profile).to receive(:[]).with('name').at_least(:once).and_call_original
      expect(profile).to receive(:[]).with('taskUri').and_call_original
      expect(profile).to receive(:[]).with('state').and_return('Creating', 'Normal')
      expect(@ov_200).to receive(:wait_for).with('/rest/fake').and_return true
      expect(profile).to receive(:refresh).and_return true
      @driver_200.instance_eval { wait_for_profile(a, n, profile) }
    end
  end

end
