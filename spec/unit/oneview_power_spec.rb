require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#power_on' do
    it 'calls set_power_state with correct params' do
      a = action_handler
      m = machine_spec
      ret_val = @instance.instance_eval { power_on(a, m) }
      expect(a_request(:get, %r{/rest/server-hardware/.*})).to have_been_made
      expect(a_request(:put, %r{/rest/server-hardware/.*/powerState}).with(body: '{"powerState":"On","powerControl":"MomentaryPress"}')).to have_been_made
      expect(ret_val).to match(%r{\/rest\/server-hardware\/.+})
    end

    it 'allows hardware_uri to be passed in' do
      a = action_handler
      m = machine_spec
      @instance.instance_eval { power_on(a, m, '/rest/server-hardware/31363636-3136-584D-5132-333230314D38') }
      expect(a_request(:get, %r{/rest/server-profiles})).to_not have_been_made
    end
  end

  describe '#power_off' do
    it 'calls set_power_state with correct params' do
      a = action_handler
      m = machine_spec
      ret_val = @instance.instance_eval { power_off(a, m) }
      expect(ret_val).to match(%r{\/rest\/server-hardware\/.+})
      expect(a_request(:put, %r{/rest/server-hardware/.*/powerState}).with(body: '{"powerState":"Off","powerControl":"MomentaryPress"}')).to have_been_made
    end

    it 'allows hardware_uri to be passed in' do
      a = action_handler
      m = machine_spec
      @instance.instance_eval { power_off(a, m, '/rest/server-hardware/31363636-3136-584D-5132-333230314D38') }
      expect(a_request(:get, %r{/rest/server-profiles})).to_not have_been_made
    end
  end

  describe '#set_power_state' do

    it 'fails when an invalid state is requested' do
      a = action_handler
      m = machine_spec
      expect { @instance.instance_eval { set_power_state(a, m, :invalid) } }.to raise_error('Invalid power state invalid')
    end

  end

end
