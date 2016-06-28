module OneviewChefProvisioningDriver
  # Helpers for OneView actions
  module OneViewHelper
    # Create new Profile from template or server profile
    # @return [OneviewSDK::ServerProfile] server profile
    def profile_from_template(template_name, profile_name)
      raise 'Template name missing! Please set machine_options[:driver_options][:server_template]' unless template_name
      if @ov.api_version >= 200
        # Look for Server Profile Template (OneView 2.0 or higher)
        template = OneviewSDK::ServerProfileTemplate.find_by(@ov, name: template_name).first
        return template.new_profile(profile_name) if template
      end

      # Look for Server Profile as second option
      profile = OneviewSDK::ServerProfile.find_by(@ov, name: template_name).first
      raise "Template '#{template_name}' not found! Please match the template name with one that exists on OneView." unless profile
      profile['name'] = profile_name

      # Remove unwanted fields
      %w(uri serialNumber uuid taskUri).each { |key| profile[key] = nil }
      profile['connections'].each do |c|
        %w(wwnn wwpn mac deploymentStatus interconnectUri wwpnType macType).each { |key| c[key] = nil }
      end
      profile
    end

    # Get an available hardware for a template. If a specific location is requested, find it
    # @return [OneviewSDK::ServerHardware]
    def available_hardware_for_profile(profile, location = nil)
      Chef::Log.debug "Specific hardware requested: #{location}" if location
      hw_list = profile.available_hardware
      raise 'Error! No available blades that are compatible with the server template!' if hw_list.empty?
      if location
        chosen_blade = hw_list.find { |h| h['name'] == location }
        return chosen_blade if chosen_blade
        raise "Specified hardware '#{location}' doesn't exist or doesn't match the given template"
      end
      hw_list.first # If no location is specified, return the first matching HW
    end

    # Wait for the profile to finish being applied
    # @return [TrueClass, FalseClass]
    def wait_for_profile(action_handler, machine_name, profile)
      return true if profile['state'] == 'Normal'
      action_handler.perform_action "Apply profile '#{profile['name']}' for machine '#{machine_name}'" do
        action_handler.report_progress "INFO: Applying profile '#{profile['name']}' for machine '#{machine_name}'"
        @ov.wait_for(profile['taskUri'])
      end
      profile.refresh
      raise "Server profile state '#{profile['state']}' not 'Normal'" unless profile['state'] == 'Normal'
    end
  end
end
