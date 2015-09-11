module ICspAPIv104
  # Parse and clean connection data for api call
  def icsp_v104_parse_connection(machine_options, c)
    allowed_keys = %w(macAddress enabled dhcpv4 ipv6autoconfig provisioning dnsServers winsServers dnsSearch staticNetworks vlanid ipv4gateway ipv6gateway)
    c[:enabled]     ||= true
    c[:vlanid]      ||= '-1'
    c[:dhcpv4]      ||= c[:dhcp]
    c[:ipv4gateway] ||= c[:gateway] || machine_options[:driver_options][:gateway]
    c[:ipv4gateway]   = nil if c[:ipv4gateway] == :none
    c[:dnsServers]  ||= c[:dns] || machine_options[:driver_options][:dns] || []
    c[:dnsServers]    = nil if c[:dnsServers] == :none
    c[:dnsServers]    = c[:dnsServers].split(',') if c[:dnsServers].class == String
    c[:staticNetworks] ||= ["#{c[:ip4Address]}/#{c[:mask] || machine_options[:driver_options][:mask] || '24'}"] if c[:ip4Address]
    c.keep_if {|k, _v| allowed_keys.include? k.to_s }
  end

  # Parse and clean personality_data data for api call
  def icsp_v104_build_personality_data(machine_options, nics)
    allowed_keys = %w(hostname domain workgroup)
    personality_data = Marshal.load(Marshal.dump(machine_options[:driver_options])) || {}
    personality_data.keep_if {|k, _v| allowed_keys.include? k.to_s }
    personality_data['hostname'] ||= machine_options[:driver_options][:host_name]
    personality_data['domain']   ||= machine_options[:driver_options][:domainName]
    personality_data['interfaces'] = nics
    personality_data
  end
end
