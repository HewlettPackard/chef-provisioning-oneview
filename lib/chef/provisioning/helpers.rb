require_relative 'create_machine'
require_relative 'customize_machine'
require_relative 'oneview/oneview_helper'
require_relative 'oneview/san_storage'
require_relative 'icsp/icsp_helper'

module OneviewChefProvisioningDriver
  module Helpers
    include CreateMachine # Handles allocation of OneView ServerProfile
    include CustomizeMachine # Handles OS install and network configuration

    include OneViewHelper # Helpers for OneView actions
    include OneViewSanStorage # Helpers for OneView SAN storage actions

    include IcspHelper # Helpers for ICSP actions
  end
end
