# Methods for configuring SAN storage on OneView
module OneViewSanStorage
  def fill_volume_details(v)
    details = rest_api(:oneview, :get, v['volumeUri'])
    v['volumeName'] = details['name']
    v['permanent'] = details['isPermanent']
    v['volumeShareable'] = details['shareable']
    v['volumeProvisionType'] = details['provisionType']
    v['volumeProvisionedCapacityBytes'] = details['provisionedCapacity']
    v['volumeDescription'] = details['description']
    v
  end

  # Prepare profile for SAN storage
  def update_san_info(machine_spec, profile)
    san_storage = profile['sanStorage']
    return profile unless san_storage && !san_storage['volumeAttachments'].empty?

    # Sanitize old SAN entries and fill in details
    boot_vols = []
    san_storage['volumeAttachments'].each do |v|
      fill_volume_details(v) unless profile['serverProfileTemplateUri']
      fail "#{machine_spec.name}: Should know if volume is sharable:\n#{v}" unless v.key?('volumeShareable')

      # Match boot disks by name
      boot_vols.push(v['volumeName']) if v['volumeName'].downcase.match(/^boot/)
      v['volumeName'] += " #{profile['name']}" unless v['volumeShareable'] # Append profile name to volume name

      unless profile['serverProfileTemplateUri'] # Only needed when coppied from profile
        v['state'] = nil
        v['status'] = nil
        v['storagePaths'].each { |s| s['status'] = nil }

        unless v['volumeShareable']
          # It is private in the profile, so we will clone it
          v['volumeUri'] = nil

          # Assumes all cloned volumes are non-permanet. Might want some global config to control this
          v['permanent'] = false
          v['lun'] = nil if v['lunType'].downcase == 'auto'
        end
      end
    end
    fail "#{machine_spec.name}: There should only be 1 SAN boot volume. Boot volumes: #{boot_vols}" if boot_vols.size > 1
    profile
  end

  # Make sure connections for SAN boot volumes are configured to boot from the correct SAN volume
  def enable_boot_from_san(action_handler, machine_spec, profile)
    return false if profile['connections'].nil? || profile['connections'].empty?

    # If there is a san volume we might need to update boot connections
    update_needed = false
    profile['sanStorage']['volumeAttachments'].each do |v|
      vol_details = rest_api(:oneview, :get, v['volumeUri'])
      next unless vol_details['name'].downcase.match(/^boot/)
      # Find the enabled path(s), get target wwpn, and then update connection, setting boot targets
      v['storagePaths'].each do |s|
        next if !s['isEnabled'] || s['storageTargets'].nil? || s['storageTargets'].empty?
        connection = profile['connections'].find { |c| c['id'] == s['connectionId'] }
        fail "#{machine_spec.name}: Connection #{s['connectionId']} not found! Check SAN settings" unless connection
        if connection['boot'].nil? || connection['boot']['priority'] == 'NotBootable'
          msg = "#{machine_spec.name}: Connection #{s['connectionId']} is labeled for boot, but the connection is not marked as bootable."
          fail "#{msg} Set the connection boot target to Primary or Secondary"
        end
        target = {}
        target['arrayWwpn'] = s['storageTargets'].first.delete(':')
        target['lun'] = v['lun']
        unless connection['boot']['targets'] && connection['boot']['targets'].first &&
               connection['boot']['targets'].first['arrayWwpn'] == target['arrayWwpn'] &&
               connection['boot']['targets'].first['lun'] == target['lun']
          connection['boot']['targets'] = [target]
          update_needed = true
        end
      end
    end

    if update_needed
      action_handler.perform_action "Enable SAN-bootable connections for #{machine_spec.name}" do
        action_handler.report_progress "INFO: Enabling SAN-bootable connections for #{machine_spec.name}"
        power_off(action_handler, machine_spec, profile['serverHardwareUri'])
        task = rest_api(:oneview, :put, profile['uri'], { 'body' => profile })
        task = oneview_wait_for(task['uri'], 90) # Wait for up to 15 min for profile to be updated
        fail "Timed out waiting for enabling SAN-bootable connections on #{machine_spec.name}" if task == false
        fail "Error enabling SAN-bootable connections on #{machine_spec.name}. Response: #{task}" unless task == true
      end
      profile = rest_api(:oneview, :get, profile['uri'])
    end
    profile # Return profile
  end
end
