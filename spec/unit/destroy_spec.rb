require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#destroy_oneview_profile' do
    it 'destroys the profile' do
      a = action_handler
      m = machine_spec
      @instance.instance_eval { destroy_oneview_profile(a, m) }
      expect(a_request(:get, %r{/rest/server-hardware/.*})).to have_been_made
      expect(a_request(:get, %r{/rest/tasks/.*})).to have_been_made
      expect(a_request(:delete, %r{/rest/server-profiles/.*})).to have_been_made
    end
  end

  describe '#destroy_icsp_server' do
    it 'destroys the server' do
      a = action_handler
      m = machine_spec
      @instance.instance_eval { destroy_icsp_server(a, m) }
      expect(a_request(:delete, %r{/rest/os-deployment-servers/.*})).to have_been_made
    end
  end

end
