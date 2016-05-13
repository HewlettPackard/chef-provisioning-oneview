require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe 'login functions' do

    it 'can parse the oneview sessionID' do
      expect(@instance.instance_eval { login_to_oneview }).to match(@oneview_key)
    end

    it 'can parse the icsp sessionID' do
      expect(@instance.instance_eval { login_to_icsp }).to match(@icsp_key)
    end
  end

end
