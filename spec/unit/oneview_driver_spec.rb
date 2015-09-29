require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#canonicalize_url' do
    it 'canonicalizes the url' do
      url = 'https://oneview.domain.com'
      config = {}
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url("oneview:#{url}", config)).to eq("oneview:#{url}")
    end

    it 'canonicalizes the url from the config' do
      url = 'https://oneview.domain.com'
      config = { knife: { oneview_url: url } }
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url('oneview:', config)).to eq("oneview:#{url}")
    end
  end

  describe '#initialize' do

    it 'reads all necessary values from knife config during initialization' do
      expect(@instance.instance_variable_get('@oneview_base_url')).to eq('https://my-oneview.my-domain.com')
      expect(@instance.instance_variable_get('@oneview_username')).to eq('Administrator')
      expect(@instance.instance_variable_get('@oneview_password')).to eq('password12')
      expect(@instance.instance_variable_get('@oneview_disable_ssl')).to eq(true)

      expect(@instance.instance_variable_get('@icsp_base_url')).to eq('https://my-icsp.my-domain.com')
      expect(@instance.instance_variable_get('@icsp_username')).to eq('administrator')
      expect(@instance.instance_variable_get('@icsp_password')).to eq('password123')
      expect(@instance.instance_variable_get('@icsp_disable_ssl')).to eq(nil)
    end

    it 'uses the correct api versions' do
      expect(@instance.instance_variable_get('@oneview_api_version')).to eq(120)
      expect(@instance.instance_variable_get('@icsp_api_version')).to eq(102)
      expect(@instance.instance_variable_get('@current_oneview_api_version')).to eq(120)
      expect(@instance.instance_variable_get('@current_icsp_api_version')).to eq(102)
    end

    it 'requires the oneview_url knife param' do
      knife_config[:knife].delete(:oneview_url)
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config) }.to raise_error('Must set the knife[:oneview_url] attribute!')
    end

    it 'requires the oneview_username knife param' do
      knife_config[:knife].delete(:oneview_username)
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config) }.to raise_error('Must set the knife[:oneview_username] attribute!')
    end

    it 'requires the oneview_password knife param' do
      knife_config[:knife].delete(:oneview_password)
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config) }.to raise_error('Must set the knife[:oneview_password] attribute!')
    end

    it 'requires the icsp_url knife param' do
      knife_config[:knife].delete(:icsp_url)
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config) }.to raise_error('Must set the knife[:icsp_url] attribute!')
    end

    it 'requires the icsp_username knife param' do
      knife_config[:knife].delete(:icsp_username)
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config) }.to raise_error('Must set the knife[:icsp_username] attribute!')
    end

    it 'requires the icsp_password knife param' do
      knife_config[:knife].delete(:icsp_password)
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, knife_config) }.to raise_error('Must set the knife[:icsp_password] attribute!')
    end
  end
end
