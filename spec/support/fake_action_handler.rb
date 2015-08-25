module ChefProvisioningOneviewHelpers
  class FakeActionHandler < Chef::Provisioning::ActionHandler
    def puts(*)
    end
  end
end
