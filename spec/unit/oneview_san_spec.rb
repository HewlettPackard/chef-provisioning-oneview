require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#fill_volume_details' do
    it 'fills the correct volume details' do
      profile = @instance.instance_eval { get_oneview_template('Template - Web Server with SAN') }
      v = profile['sanStorage']['volumeAttachments'].first
      expect(v['volumeName']).to be_nil
      expect(v['volumeShareable']).to be_nil
      @instance.instance_eval { fill_volume_details(v) }
      expect(a_request(:get, /#{v['volumeUri']}/)).to have_been_made
      expect(v['volumeName']).to eq('bootVol')
      expect(v['volumeShareable']).to be false
    end
  end

  describe '#update_san_info' do
    context 'profile coppies (OV 1.2)' do
      it 'prepares copies of profiles for SAN storage' do
        m = machine_spec
        profile = @instance.instance_eval { get_oneview_template('Template - Web Server with SAN') }
        profile['name'] = 'web01'
        ret_val = @instance.instance_eval { update_san_info(m, profile) }
        v = ret_val['sanStorage']['volumeAttachments'].first
        expect(v['uri']).to be_nil
        expect(v['volumeName']).to eq('bootVol web01')
        expect(v['lun']).to eq('0')
      end
    end

    context 'Server Profile Templates (OV 2.0)' do
      before :each do
        @instance.instance_variable_set('@current_oneview_api_version', 200)
      end

      it 'leaves profiles from Templates largely the same' do
        m = machine_spec
        profile = @instance.instance_eval { get_oneview_template('Web Server Template with SAN') }
        ret_val = @instance.instance_eval { update_san_info(m, profile) }
        expect(ret_val['sanStorage']['volumeAttachments'].first['storagePaths'].first.key?('state')).to be false
      end

      it 'appends the profile name to the volume name' do
        m = machine_spec
        profile = @instance.instance_eval { get_oneview_template('Web Server Template with SAN') }
        profile['name'] = 'web01'
        ret_val = @instance.instance_eval { update_san_info(m, profile) }
        expect(ret_val['sanStorage']['volumeAttachments'].first['volumeName']).to eq('bootVol web01')
      end

      it 'requires profiles to specify the volumeShareable attribute' do
        m = machine_spec
        profile = @instance.instance_eval { get_oneview_template('Web Server Template with SAN') }
        profile['sanStorage']['volumeAttachments'].first.delete('volumeShareable')
        expect { @instance.instance_eval { update_san_info(m, profile) } }.to raise_error(/Should know if volume is sharable/)
      end

      it 'only allows 1 SAN boot volume' do
        m = machine_spec
        profile = @instance.instance_eval { get_oneview_template('Web Server Template with SAN') }
        profile['sanStorage']['volumeAttachments'].push('id' => 2, 'volumeName' => 'bootVol2', 'volumeShareable' => true)
        expect { @instance.instance_eval { update_san_info(m, profile) } }.to raise_error(/should only be 1 SAN boot volume/)
      end
    end
  end

  describe '#enable_boot_from_san' do
    context 'Server Profile Templates (OV 2.0)' do
      before :each do
        @instance.instance_variable_set('@current_oneview_api_version', 200)
      end

      it 'configures connections to boot from a SAN volume' do
        a = action_handler
        m = machine_spec
        profile = @instance.instance_eval { get_oneview_profile_by_sn('VCGE9KB042') }
        ret_val = @instance.instance_eval { enable_boot_from_san(a, m, profile) }
        expect(a_request(:get, /#{profile['sanStorage']['volumeAttachments'].first['volumeUri']}/)).to have_been_made
        expect(ret_val['connections'].last['boot']['targets'].first['arrayWwpn']).to eq('21210002AC00159E')
      end
    end
  end

end
