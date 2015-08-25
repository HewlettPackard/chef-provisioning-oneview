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

    it 'gets both auth tokens via the auth_tokens method' do
      @instance.instance_eval { auth_tokens }
      expect(@instance.instance_variable_get('@oneview_key')).to match(@oneview_key)
      expect(@instance.instance_variable_get('@icsp_key')).to match(@icsp_key)
    end
  end

end
