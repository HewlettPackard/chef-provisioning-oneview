require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#create_machine' do
    before :each do
      $server_created = nil
    end

    context 'OneView 120' do
      it 'skips creating machines that already exist' do
        a = action_handler
        m = machine_spec
        o = valid_machine_options
        ret_val = @instance.instance_eval { create_machine(a, m, o) }
        expect(a_request(:post, %r{/rest/server-profiles})).to_not have_been_made
        expect(ret_val['name']).to eq('chef-web01')
      end

      it 'creates a machine from a Profile Template if it does not exist' do
        a = action_handler
        m = machine_spec
        o = valid_machine_options
        o[:driver_options][:host_name] = 'chef-web03'
        @instance.instance_eval { create_machine(a, m, o) }
        expect(a_request(:post, %r{/rest/server-profiles})).to have_been_made.times(1)
      end

      it 'sets the correct HW uri to create a machine if it does not exist' do
        a = action_handler
        m = machine_spec
        o = valid_machine_options
        o[:driver_options][:host_name] = 'chef-web03'
        @instance.instance_eval { create_machine(a, m, o) }
        expect(a_request(:post, %r{/rest/server-profiles}).with do |req|
          req.body.match('"serverHardwareUri":"/rest/server-hardware/31363636-3136-584D-5132-333230314D38"') &&
          req.body.match('"serverHardwareTypeUri":"/rest/server-hardware-types/2947DC35-BE48-4075-A3FD-254A9B42F5BD"') &&
          req.body.match('"enclosureGroupUri":"/rest/enclosure-groups/3a11ccdd-b352-4046-a568-a8b0faa6cc39"') &&
          !req.body.match('"enclosureUri":"') &&
          !req.body.match('"enclosureBay":"')
        end).to have_been_made
      end
    end

    context 'OneView 200' do
      before :each do
        @instance.instance_variable_set('@current_oneview_api_version', 200)
      end

      it 'creates a machine from a Template if it does not exist' do
        a = action_handler
        m = machine_spec
        o = valid_machine_options
        o[:driver_options][:host_name] = 'chef-web03'
        o[:driver_options][:server_template] = 'Web Server Template'
        @instance.instance_eval { create_machine(a, m, o) }
        expect(a_request(:post, %r{/rest/server-profiles})).to have_been_made.times(1)
      end

      it 'sets the correct HW uri from a Template to create a machine if it does not exist' do
        a = action_handler
        m = machine_spec
        o = valid_machine_options
        o[:driver_options][:host_name] = 'chef-web03'
        o[:driver_options][:server_template] = 'Web Server Template'
        @instance.instance_eval { create_machine(a, m, o) }
        expect(a_request(:post, %r{/rest/server-profiles}).with do |req|
          req.body.match('"serverHardwareUri":"/rest/server-hardware/37333036-3831-584D-5131-303030323037"') &&
          req.body.match('"serverHardwareTypeUri":"/rest/server-hardware-types/5B42EABE-5140-4E38-91F0-68367B529DE9"') &&
          req.body.match('"enclosureGroupUri":"/rest/enclosure-groups/c0f86584-5a82-4480-ad13-8ed6544d6c98"') &&
          !req.body.match('"enclosureUri":"') &&
          !req.body.match('"enclosureBay":"')
        end).to have_been_made
      end
    end
  end
end
