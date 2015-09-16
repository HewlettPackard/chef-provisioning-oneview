require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#get_oneview_profile_by_sn' do

    it 'gets profile for a valid SN' do
      ret_val = @instance.instance_eval { get_oneview_profile_by_sn('VCGE9KB041') }
      expect(ret_val).to_not be_nil
    end

    it 'returns nil for fake SN' do
      ret_val = @instance.instance_eval { get_oneview_profile_by_sn('11111BBBBB') }
      expect(ret_val).to be_nil
    end

    it 'fails when an empty SN is given' do
      expect { @instance.instance_eval { get_oneview_profile_by_sn('') } }.to raise_error('Must specify a serialNumber!')
    end

    it 'fails when an invalid filter is specified' do
      expect { @instance.instance_eval { get_oneview_profile_by_sn('INVALIDFILTER') } }.to raise_error(/Failed to get oneview profile by serialNumber/)
    end
  end

  describe '#get_oneview_template' do

    context 'OneView 120' do
      it 'gets profile template by name' do
        ret_val = @instance.instance_eval { get_oneview_template('Template - Web Server') }
        expect(ret_val['uri']).to_not be_nil
      end
    end

    context 'OneView 200' do
      before :each do
        @instance.instance_variable_set('@current_oneview_api_version', 200)
      end

      it 'gets template by name' do
        ret_val = @instance.instance_eval { get_oneview_template('Web Server Template') }
        expect(ret_val['uri']).to be_nil
        expect(ret_val['serverProfileTemplateUri']).to_not be_nil
      end

      it 'gets profile template by name' do
        ret_val = @instance.instance_eval { get_oneview_template('Template - Web Server') }
        expect(ret_val['uri']).to_not be_nil
      end
    end
  end
end
