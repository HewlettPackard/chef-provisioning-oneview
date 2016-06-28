$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-oneview'
  s.version = Chef::Provisioning::ONEVIEW_DRIVER_VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE']
  s.summary = 'Chef Provisioning driver for OneView'
  s.description = 'Chef Provisioning driver for creating and managing OneView infrastructure.'
  s.author = 'Hewlett Packard Enterprise'
  s.email = ['jared.smartt@hp.com', 'gunjan.kamle@hp.com', 'matthew.frahry@hp.com']
  s.homepage = 'https://github.com/HewlettPackard/chef-provisioning-oneview'

  s.add_dependency 'chef', '~> 12.0'
  s.add_dependency 'chef-provisioning', '~> 1.0'
  s.add_dependency 'oneview-sdk', '~> 1.0'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sinatra'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rubocop', '= 0.40.0'
  s.add_development_dependency 'pry'

  s.bindir       = 'bin'
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob('{distro,lib,spec}/**/*', File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
  s.license = 'Apache-2.0'
end
