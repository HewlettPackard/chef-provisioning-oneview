require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do

  let(:knife_config) {
    { knife: {
      oneview_url: 'https://my-oneview.my-domain.com',
      oneview_username: 'Administrator',
      oneview_password: 'password12',
      oneview_ignore_ssl: true,

      icsp_url: 'https://my-icsp.my-domain.com',
      icsp_username: 'administrator',
      icsp_password: 'password123',
    }}
  }
  
  describe "#canonicalize_url" do
    it "canonicalizes the url" do
      url = "https://oneview.domain.com"
      config = {}
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url("oneview:#{url}", config )).to eq("oneview:#{url}")
    end
    
    it "canonicalizes the url from the config" do
      url = "https://oneview.domain.com"
      config = { knife: {oneview_url: url} }
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url("oneview:", config )).to eq("oneview:#{url}")
    end
  end
  
  describe "#initialize" do
    before :each do
      @url = "https://oneview.domain.com"
      canonical_url = "oneview:#{@url}"
      @instance = Chef::Provisioning::OneViewDriver.new(canonical_url, knife_config)
    end
    
    it "reads all necessary values from knife config during initialization" do
      expect(@instance.instance_variable_get("@oneview_base_url")).to eq('https://my-oneview.my-domain.com')
      expect(@instance.instance_variable_get("@oneview_username")).to eq('Administrator')
      expect(@instance.instance_variable_get("@oneview_password")).to eq('password12')
      expect(@instance.instance_variable_get("@oneview_disable_ssl")).to eq(true)
      expect(@instance.instance_variable_get("@oneview_api_version")).to eq('1.20')
      expect(@instance.instance_variable_get("@oneview_key")).to eq('long_oneview_key')
      
      expect(@instance.instance_variable_get("@icsp_base_url")).to eq('https://my-icsp.my-domain.com')
      expect(@instance.instance_variable_get("@icsp_username")).to eq('administrator')
      expect(@instance.instance_variable_get("@icsp_password")).to eq('password123')
      expect(@instance.instance_variable_get("@icsp_disable_ssl")).to eq(nil)
      expect(@instance.instance_variable_get("@icsp_api_version")).to eq('120')
      expect(@instance.instance_variable_get("@icsp_key")).to eq('long_icsp_key')
    end
    
  end
  
end
