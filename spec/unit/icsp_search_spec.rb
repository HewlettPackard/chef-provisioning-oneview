require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#get_icsp_server_by_sn' do

    it 'gets info for a valid SN' do
      ret_val = @instance.instance_eval { get_icsp_server_by_sn('VCGE9KB041') }
      expect(ret_val['serialNumber']).to eq('VCGE9KB041')
      expect(ret_val['uri']).to match(%r{\/rest\/os-deployment-servers\/.+})
    end

    it 'returns nil for fake SN' do
      ret_val = @instance.instance_eval { get_icsp_server_by_sn('FAKESN') }
      expect(ret_val).to be_nil
    end

    it 'fails when an empty SN is given' do
      expect { @instance.instance_eval { get_icsp_server_by_sn('') } }.to raise_error('Must specify a serialNumber!')
    end

  end

end
