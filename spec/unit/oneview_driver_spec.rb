require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do

  describe '#canonicalize_url' do
    it 'requires a oneview url' do
      expect { Chef::Provisioning::OneViewDriver.canonicalize_url('oneview', {}) }
        .to raise_error(/Must set the oneview driver url!/)
    end

    it 'splits the url and driver name apart' do
      driver = "oneview:#{@oneview_url}"
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url(driver, {})).to eq(@canonical_url)
    end

    it 'respects driver_options[:url]' do
      driver = 'oneview'
      config = { driver_options: { oneview: { url: @oneview_url } } }
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url(driver, config)).to eq(@canonical_url)
    end

    it 'respects knife[:oneview_url]' do
      driver = 'oneview'
      config = { knife: { oneview_url: @oneview_url } }
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url(driver, config)).to eq(@canonical_url)
    end

    it "respects ENV['ONEVIEWSDK_URL']" do
      driver = 'oneview'
      ENV['ONEVIEWSDK_URL'] = @oneview_url
      expect(Chef::Provisioning::OneViewDriver.canonicalize_url(driver, {})).to eq(@canonical_url)
    end
  end

  describe '#initialize' do
    it 'reads the driver_options hash with defaults' do
      config = {
        driver_options: {
          oneview: { user: @oneview_user, password: @oneview_password },
          icsp: { url: @icsp_url, user: @icsp_user, password: @icsp_password }
        },
        knife: {}
      }
      driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, config)

      # OneView defaults:
      ov = driver.instance_variable_get('@ov')
      expect(ov.url).to eq(@oneview_url)
      expect(ov.password).to eq(@oneview_password)
      expect(ov.token).to eq(@oneview_token)
      expect(ov.api_version).to eq(200)
      expect(ov.ssl_enabled).to eq(true)
      expect(ov.print_wait_dots).to eq(true)
      expect(ov.logger).to eq(Chef::Log)
      expect(ov.log_level).to eq(Chef::Log.level)
      expect(ov.timeout).to eq(nil)

      # ICSP defaults:
      expect(driver.instance_variable_get('@icsp_base_url')).to eq(@icsp_url)
      expect(driver.instance_variable_get('@icsp_username')).to eq(@icsp_user)
      expect(driver.instance_variable_get('@icsp_password')).to eq(@icsp_password)
      expect(driver.instance_variable_get('@icsp_disable_ssl')).to eq(false)
      expect(driver.instance_variable_get('@icsp_api_version')).to eq(102)
      expect(driver.instance_variable_get('@icsp_ignore')).to eq(false)
      expect(driver.instance_variable_get('@icsp_key')).to eq(@icsp_key)
      expect(driver.instance_variable_get('@icsp_timeout')).to eq(nil)
    end

    it 'reads knife config values' do
      config = {
        knife: {
          oneview_username: @oneview_user, oneview_password: @oneview_password,
          oneview_ignore_ssl: true, oneview_timeout: 7, icsp_url: @icsp_url, icsp_timeout: 8,
          icsp_username: @icsp_user, icsp_password: @icsp_password, icsp_ignore_ssl: true
        }
      }
      driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, config)

      # OneView:
      ov = driver.instance_variable_get('@ov')
      expect(ov.user).to eq(@oneview_user)
      expect(ov.password).to eq(@oneview_password)
      expect(ov.token).to eq(@oneview_token)
      expect(ov.api_version).to eq(200)
      expect(ov.ssl_enabled).to eq(false)
      expect(ov.print_wait_dots).to eq(true)
      expect(ov.timeout).to eq(7)
      expect(ov.logger).to eq(Chef::Log)
      expect(ov.log_level).to eq(Chef::Log.level)

      # ICSP:
      expect(driver.instance_variable_get('@icsp_base_url')).to eq(@icsp_url)
      expect(driver.instance_variable_get('@icsp_username')).to eq(@icsp_user)
      expect(driver.instance_variable_get('@icsp_password')).to eq(@icsp_password)
      expect(driver.instance_variable_get('@icsp_disable_ssl')).to eq(true)
      expect(driver.instance_variable_get('@icsp_api_version')).to eq(102)
      expect(driver.instance_variable_get('@icsp_ignore')).to eq(false)
      expect(driver.instance_variable_get('@icsp_key')).to eq(@icsp_key)
      expect(driver.instance_variable_get('@icsp_timeout')).to eq(8)
    end

    it 'reads ONEVIEWSDK user and password environment variables' do
      config = { driver_options: {}, knife: {} }
      ENV['ONEVIEWSDK_USER'] = @oneview_user
      ENV['ONEVIEWSDK_PASSWORD'] = @oneview_password
      allow(Chef::Log).to receive(:warn).with(/ICSP/).and_return true
      driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, config)
      ov = driver.instance_variable_get('@ov')
      expect(ov.user).to eq(@oneview_user)
      expect(ov.password).to eq(@oneview_password)
    end

    it 'reads ONEVIEWSDK token and ssl environment variables' do
      config = { driver_options: {}, knife: {} }
      ENV['ONEVIEWSDK_TOKEN'] = @oneview_token
      ENV['ONEVIEWSDK_SSL_ENABLED'] = 'false'
      allow(Chef::Log).to receive(:warn).with(/ICSP/).and_return true
      driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, config)
      ov = driver.instance_variable_get('@ov')
      expect(ov.token).to eq(@oneview_token)
    end

    it 'allows the driver_options hash to override defaults' do
      config = {
        driver_options: {
          oneview: { token: @oneview_token, ssl_enabled: false, timeout: 7, print_wait_dots: false },
          icsp: { url: @icsp_url, user: @icsp_user, password: @icsp_password, ssl_enabled: false, timeout: 8 }
        },
        knife: {}
      }
      driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, config)

      # OneView defaults:
      ov = driver.instance_variable_get('@ov')
      expect(ov.user).to be_nil
      expect(ov.password).to be_nil
      expect(ov.token).to eq(@oneview_token)
      expect(ov.api_version).to eq(200)
      expect(ov.ssl_enabled).to eq(false)
      expect(ov.print_wait_dots).to eq(false)
      expect(ov.timeout).to eq(7)

      # ICSP defaults:
      expect(driver.instance_variable_get('@icsp_base_url')).to eq(@icsp_url)
      expect(driver.instance_variable_get('@icsp_username')).to eq(@icsp_user)
      expect(driver.instance_variable_get('@icsp_password')).to eq(@icsp_password)
      expect(driver.instance_variable_get('@icsp_disable_ssl')).to eq(true)
      expect(driver.instance_variable_get('@icsp_api_version')).to eq(102)
      expect(driver.instance_variable_get('@icsp_ignore')).to eq(false)
      expect(driver.instance_variable_get('@icsp_key')).to eq(@icsp_key)
      expect(driver.instance_variable_get('@icsp_timeout')).to eq(8)
    end

    it 'requires a oneview password or token' do
      config = { driver_options: {}, knife: {} }
      expect(Chef::Log).to receive(:warn).with(/User option not set/).and_return true
      expect { Chef::Provisioning::OneViewDriver.new(@canonical_url, config) }
        .to raise_error(/Must set user & password options or token/)
    end

    context 'with ICSP disabled' do
      before :each do
        @config = {
          driver_options: {
            oneview: { token: @oneview_token },
            icsp: { url: @icsp_url, user: @icsp_user, password: @icsp_password }
          },
          knife: {}
        }
      end

      it 'disables ICSP if the url is not specified' do
        @config[:driver_options][:icsp].delete(:url)
        expect(Chef::Log).to receive(:warn).with(/ICSP url not set/)
        driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, @config)
        expect(driver.instance_variable_get('@icsp_ignore')).to eq(true)
      end

      it 'disables ICSP if the user is not specified' do
        @config[:driver_options][:icsp].delete(:user)
        expect(Chef::Log).to receive(:warn).with(/ICSP user not set/)
        driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, @config)
        expect(driver.instance_variable_get('@icsp_ignore')).to eq(true)
      end

      it 'disables ICSP if the password is not specified' do
        @config[:driver_options][:icsp].delete(:password)
        expect(Chef::Log).to receive(:warn).with(/ICSP password not set/)
        driver = Chef::Provisioning::OneViewDriver.new(@canonical_url, @config)
        expect(driver.instance_variable_get('@icsp_ignore')).to eq(true)
      end
    end
  end
end
