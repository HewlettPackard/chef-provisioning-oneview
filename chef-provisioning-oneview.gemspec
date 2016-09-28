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
  s.email = ['jared.smartt@hpe.com', 'gunjan.kamle@hpe.com', 'matthew.frahry@hpe.com']
  s.homepage = 'https://github.com/HewlettPackard/chef-provisioning-oneview'
  s.license = 'Apache-2.0'

  case RUBY_VERSION
  when /^2\.0/
    s.add_dependency 'chef', '~> 12.0', '< 12.9'
  when /^2\.(1|2\.[01])/
    s.add_dependency 'chef', '~> 12.0', '< 12.14'
  else
    s.add_dependency 'chef', '~> 12.0'
  end
  s.add_dependency 'oneview-sdk', '~> 2.1'
  s.add_dependency 'chef-provisioning', '~> 1.0'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sinatra'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rubocop', '= 0.40.0'
  s.add_development_dependency 'pry'

  s.require_path = 'lib'

  all_files = `git ls-files -z`.split("\x0")
  s.files = Dir['LICENSE', 'README.md', '*.gemspec', 'lib/**/*'].reject { |f| !all_files.include?(f) }
end
