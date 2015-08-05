$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/oneview/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-oneview'
  s.version = Chef::Provisioning::ONEVIEW_DRIVER_VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Chef Provisioning driver for OneView'
  s.description = 'Chef Provisioning driver for creating and managing OneView infrastructure.'
  s.author = 'Hewlett Packard'
  s.email = 'jared.smartt@hp.com'
  s.homepage = 'https://github.com/HewlettPackard/chef-provisioning-oneview'

  s.add_dependency 'chef', '~> 12'
  s.add_dependency 'chef-provisioning', '>= 0.19.0'
  s.add_dependency 'ridley', '~> 4.2'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md CHANGELOG.md) + Dir.glob("{distro,lib,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
  s.license = "Apache-2.0"
end
