module ChefProvisioningOneviewHelpers
  class FakeMachineSpec
    attr_reader :name
    attr_accessor :data

    def initialize(name, sn)
      @name = name
      @sn = sn
      @data = {}
    end

    def reference
      ver = Chef::Provisioning::ONEVIEW_DRIVER_VERSION
      {
        'serial_number' => @sn, serial_number: @sn,
        'driver_version' => ver, driver_version: ver
      }
    end
  end
end
