#SSL: Trusting The Chef Server's Invalid Certs (for Ruby libraries like Net::SSH and Ridley)

###On Windows (requires git bash & it's linux tools):
```
# Download and convert the cert:
$ SERVER="my-server.domain.com"
$ openssl s_client -connect $SERVER:443 | tee /C/opscode/chefdk/embedded/ssl/certs/$SERVER.crt
$ openssl x509 -in /C/opscode/chefdk/embedded/ssl/certs/$SERVER.crt -out /C/opscode/chefdk/embedded/ssl/certs/$SERVER.pem -outform PEM
 
# To add it to Ruby's trusted store:
$ echo -e "\nChef Server at $SERVER\n=========================================" >> /C/opscode/chefdk/embedded/ssl/certs/cacert.pem
$ cat /C/opscode/chefdk/embedded/ssl/certs/$SERVER.pem >> /C/opscode/chefdk/embedded/ssl/certs/cacert.pem
```


###On RHEL Systems:
As root...
```
# as root...
# Download and convert the cert:
$ SERVER="my-server.domain.com"
$ openssl s_client -showcerts -connect $SERVER:443 </dev/null 2>/dev/null | tee /etc/pki/tls/certs/$SERVER.crt
$ openssl x509 -in /etc/pki/tls/certs/$SERVER.crt -out /etc/pki/ca-trust/source/anchors/$SERVER.pem -outform PEM
 
# To add it to Ruby's trusted store:
$ gem which rubygems      # Should return /opt/chefdk/embedded/lib/ruby/site_ruby/2.1.0/rubygems.rb
$ echo -e "\nChef Server at $SERVER\n=========================================" >> /opt/chefdk/embedded/ssl/certs/cacert.pem
$ cat /etc/pki/ca-trust/source/anchors/$SERVER.pem >> /opt/chefdk/embedded/ssl/certs/cacert.pem
 
# To also trust it for the rest of the OS (ie curl, etc.):
# Note: Depends on the 2 openssl commands above being run already. It looks for & adds .pem files in /etc/pki/ca-trust/source/anchors/
$ update-ca-trust force-enable
$ update-ca-trust
$ curl -I https://$SERVER # Should not give SSL error
```
