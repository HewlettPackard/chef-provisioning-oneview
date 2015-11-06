#
# Cookbook Name:: my_apache_server
# Recipe:: default
#
# Copyright (C) 2015 HP
#
# All rights reserved - Do Not Redistribute
#

package 'httpd' do
  action :install
end

file '/etc/httpd/conf.d/welcome.conf' do
  action :delete
  notifies :restart, 'service[httpd]', :delayed
end

document_root = '/var/www/oneview'
template '/etc/httpd/conf.d/oneview.conf' do
  source 'custom.erb'
  mode '0644'
  variables(
    :document_root => document_root,
    :port => 80
  )
end

directory document_root do
  mode '0755'
  recursive true
end

remote_directory document_root do
  files_mode '0755'
  source 'oneview'
  notifies :restart, 'service[httpd]', :delayed
  sensitive true
end

service 'httpd' do
  action [ :enable, :start ]
end
