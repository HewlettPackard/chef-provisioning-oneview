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

end
