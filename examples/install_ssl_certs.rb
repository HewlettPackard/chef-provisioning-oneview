require 'net/http'
require 'ridley'

script_dir = File.expand_path File.dirname(__FILE__)

def ssl_verify(url, cert_file = ENV['SSL_CERT_FILE'])
  uri = URI.parse(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', ca_file: cert_file) do |_http|
    return true
  end
rescue OpenSSL::SSL::SSLError
  return nil
end

def install_cert(url, cert_file = ENV['SSL_CERT_FILE'], name = 'Chef Server')
  uri = URI.parse(url)
  pem = Net::HTTP.start(uri.host, uri.port, { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE }) do |http|
    http.peer_cert.to_pem
  end

  fail "Could not download cert from #{url}. You may have to do it manually, and append it to '#{cert_file}'" if pem.nil?

  print "  Writing #{uri.host} cert to '#{cert_file}'..."
  open(cert_file, 'ab') do |f|
    s = "\n#{name} at #{uri.host}"
    f.write "#{s}\n"
    f.write "#{'=' * (s.length - 1)}\n"
    f.write "#{pem}"
  end
  puts " Done! \n"
end

knife_location = File.expand_path("#{script_dir}/.chef/knife.rb")
fail "Error! knife.rb file not found at '#{knife_location}'!" unless File.exist?(knife_location)
config = Ridley::Chef::Config.new(knife_location).to_hash
chef_server_url = config[:chef_server_url]
chef_server_url.sub! ':443', '' if chef_server_url
supermarket_site = config[:knife][:supermarket_site] rescue nil


puts "============================Adding certs to system keystores============================\n"
keystores = []
keystores.push ENV['SSL_CERT_FILE'] if ENV['SSL_CERT_FILE']
['c:/Program Files (x86)/Git/bin/curl-ca-bundle.crt',
 'c:/opscode/chefdk/embedded/ssl/certs/cacert.pem',
 '/opt/chefdk/embedded/ssl/certs/cacert.pem'
].each do |ca_bundle|
  keystores.push(ca_bundle) if File.exist?(ca_bundle) && !keystores.include?(ca_bundle)
end

keystores.each do |keystore|
  puts "\nKeystore #{keystore}"

  if ssl_verify(chef_server_url, keystore)
    puts "  #{URI.parse(chef_server_url).host}: Nothing to do"
  else
    install_cert(chef_server_url, keystore)
  end

  if supermarket_site
    if ssl_verify(supermarket_site, keystore)
      puts "  #{URI.parse(supermarket_site).host}: Nothing to do"
    else
      install_cert(supermarket_site, keystore, 'Chef Private Supermarket')
    end
  end
end

puts "\n\n============================Adding cert(s) to knife's trusted list============================\n\n"
system "knife ssl fetch #{chef_server_url}"
system "knife ssl fetch #{supermarket_site}" if supermarket_site
