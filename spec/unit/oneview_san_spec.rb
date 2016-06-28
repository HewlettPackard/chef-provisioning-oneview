require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  let(:vol_details) do
    {
      'name' => 'boot',
      'isPermanent' => false,
      'shareable' => false,
      'provisionType' => 'Thin',
      'provisionedCapacity' => '100000',
      'description' => 'fakeDescription'
    }
  end

  describe '#fill_volume_details' do
    it 'fills the correct volume details' do
      v = { 'name' => 'old', 'volumeUri' => '/rest/fake' }
      expect(@ov_200).to receive(:rest_get).with('/rest/fake').and_return(FakeResponse.new(vol_details))
      res = @driver_200.instance_eval { fill_volume_details(v) }
      expect(res).to eq(v)
      expect(v['volumeName']).to eq(vol_details['name'])
      expect(v['permanent']).to eq(vol_details['isPermanent'])
      expect(v['volumeShareable']).to eq(vol_details['shareable'])
      expect(v['volumeProvisionType']).to eq(vol_details['provisionType'])
      expect(v['volumeProvisionedCapacityBytes']).to eq(vol_details['provisionedCapacity'])
      expect(v['volumeDescription']).to eq(vol_details['description'])
    end
  end

  describe '#update_san_info' do
    before :each do
      allow_any_instance_of(OneviewSDK::Client).to receive(:rest_get).with(%r{/rest/storage-volumes/}).and_return(FakeResponse.new(vol_details))
    end

    let(:profile_120) do
      'spec/support/fixtures/oneview/v120/server_profile_web01_with_san_unparsed.json'
    end

    let(:profile_200) do
      'spec/support/fixtures/oneview/v200/server_profile_web01_with_san_unparsed.json'
    end

    context 'profile coppies (OV 1.2)' do
      it 'prepares copies of profiles for SAN storage' do
        profile = OneviewSDK::ServerProfile.from_file(@ov_120, profile_120)
        m = machine_spec.name
        ret_val = @driver_120.instance_eval { update_san_info(m, profile) }
        v = ret_val['sanStorage']['volumeAttachments'].first
        expect(v['uri']).to be_nil
        expect(v['volumeName']).to eq('boot web01')
        expect(v['lun']).to eq('0')
      end
    end

    context 'Server Profile Templates (OV 2.0)' do
      it 'leaves profiles from Templates largely the same' do
        m = machine_spec.name
        profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_200)
        ret_val = @driver_200.instance_eval { update_san_info(m, profile) }
        expect(ret_val['sanStorage']['volumeAttachments'].first['storagePaths'].first.key?('state')).to be false
      end

      it 'appends the profile name to the volume name' do
        m = machine_spec.name
        profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_200)
        ret_val = @driver_200.instance_eval { update_san_info(m, profile) }
        v = ret_val['sanStorage']['volumeAttachments'].first
        expect(v['volumeName']).to eq('boot web01')
      end

      it 'requires profiles to specify the volumeShareable attribute' do
        m = machine_spec.name
        profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_200)
        profile['sanStorage']['volumeAttachments'].first.delete('volumeShareable')
        expect { @driver_200.instance_eval { update_san_info(m, profile) } }.to raise_error(/Should know if volume is sharable/)
      end

      it 'only allows 1 SAN boot volume' do
        m = machine_spec.name
        profile = OneviewSDK::ServerProfile.from_file(@ov_200, profile_200)
        profile['sanStorage']['volumeAttachments'].push('id' => 2, 'volumeName' => 'bootVol2', 'volumeShareable' => true)
        expect { @driver_200.instance_eval { update_san_info(m, profile) } }.to raise_error(/should only be 1 SAN boot volume/)
      end
    end
  end

  describe '#enable_boot_from_san' do
    before :each do
      allow_any_instance_of(OneviewSDK::Client).to receive(:rest_get).with(%r{/rest/storage-volumes/}).and_return(FakeResponse.new(vol_details))
    end

    let(:profile_120) do
      'spec/support/fixtures/oneview/v120/server_profile_web01_with_san.json'
    end

    it 'configures connections to boot from a SAN volume' do
      a = action_handler
      m = machine_spec.name
      profile = OneviewSDK::ServerProfile.from_file(@ov_120, profile_120)
      profile['connections'].each { |c| c['boot'].delete('targets') }
      expect_any_instance_of(OneviewSDK::ServerHardware).to receive(:retrieve!).and_return true
      expect_any_instance_of(OneviewSDK::ServerHardware).to receive(:power_off).and_return true
      expect(profile).to receive(:update)
      expect(profile).to receive(:refresh).and_return true
      ret_val = @driver_120.instance_eval { enable_boot_from_san(a, m, profile) }
      target = ret_val['connections'].last['boot']['targets'].first
      expect(target['arrayWwpn']).to eq(ret_val['sanStorage']['volumeAttachments'].first['storagePaths'].last['storageTargets'].first.delete(':'))
      expect(target['lun']).to eq(ret_val['sanStorage']['volumeAttachments'].first['lun'])
    end

    it "doesn't update the profile if it doesn't need to" do
      a = action_handler
      m = machine_spec.name
      profile = OneviewSDK::ServerProfile.from_file(@ov_120, profile_120)
      expect(profile).to_not receive(:update)
      @driver_120.instance_eval { enable_boot_from_san(a, m, profile) }
    end

    it 'raises an error if a connection ID is invalid' do
      a = action_handler
      m = machine_spec.name
      profile = OneviewSDK::ServerProfile.from_file(@ov_120, profile_120)
      profile['sanStorage']['volumeAttachments'].first['storagePaths'].last['connectionId'] = 99
      expect { @driver_120.instance_eval { enable_boot_from_san(a, m, profile) } }.to raise_error(/Connection 99 not found/)
    end

    it 'raises an error if a connection is marked for boot but not bootable' do
      a = action_handler
      m = machine_spec.name
      profile = OneviewSDK::ServerProfile.from_file(@ov_120, profile_120)
      profile['connections'].last['boot']['priority'] = 'NotBootable'
      expect { @driver_120.instance_eval { enable_boot_from_san(a, m, profile) } }.to raise_error(/connection is not marked as bootable/)
    end
  end

end
