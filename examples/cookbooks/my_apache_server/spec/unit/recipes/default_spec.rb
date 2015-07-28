require 'spec_helper'

# default recipe
describe 'my_apache_server::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'installs httpd' do
    expect(chef_run).to install_package('httpd')
  end
  
  it 'enables httpd' do
    expect(chef_run).to enable_service('httpd')
  end
  
  it 'creates the oneview app directory' do
    expect(chef_run).to create_directory('/var/www/oneview')
  end
  
  it 'deletes the default apache welcome page config file' do
    expect(chef_run).to delete_file('/etc/httpd/conf.d/welcome.conf')
  end
  
end
