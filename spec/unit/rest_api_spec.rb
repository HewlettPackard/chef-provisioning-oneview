require_relative './../spec_helper'

RSpec.describe Chef::Provisioning::OneViewDriver do
  include_context 'shared context'

  describe '#rest_api' do

    context 'fake_oneview' do
      it 'completes get request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:oneview, :get, '/', {}) }
        expect(resp['method']).to eq('GET')
        expect(resp['message']).to eq('Fake OneView works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@oneview_api_version'))
        expect(resp['auth']).to eq(@oneview_key)
      end

      it 'completes post request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:oneview, :post, '/', {}) }
        expect(resp['method']).to eq('POST')
        expect(resp['message']).to eq('Fake OneView works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@oneview_api_version'))
        expect(resp['auth']).to eq(@oneview_key)
      end

      it 'completes put request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:oneview, :put, '/', {}) }
        expect(resp['method']).to eq('PUT')
        expect(resp['message']).to eq('Fake OneView works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@oneview_api_version'))
        expect(resp['auth']).to eq(@oneview_key)
      end

      it 'completes delete request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:oneview, :delete, '/', {}) }
        expect(resp['method']).to eq('DELETE')
        expect(resp['message']).to eq('Fake OneView works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@oneview_api_version'))
        expect(resp['auth']).to eq(@oneview_key)
      end

      it 'returns 404 error for invalid get request' do
        resp = @instance.instance_eval { rest_api(:oneview, :get, '/invalid_path', {}) }
        expect(resp['errorCode']).to eq('GENERIC_HTTP_404')
      end
    end

    context 'fake_icsp' do
      it 'completes get request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:icsp, :get, '/', {}) }
        expect(resp['method']).to eq('GET')
        expect(resp['message']).to eq('Fake ICsp works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@icsp_api_version'))
        expect(resp['auth']).to eq(@icsp_key)
      end

      it 'completes post request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:icsp, :post, '/', {}) }
        expect(resp['method']).to eq('POST')
        expect(resp['message']).to eq('Fake ICsp works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@icsp_api_version'))
        expect(resp['auth']).to eq(@icsp_key)
      end

      it 'completes put request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:icsp, :put, '/', {}) }
        expect(resp['method']).to eq('PUT')
        expect(resp['message']).to eq('Fake ICsp works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(nil)
        expect(resp['auth']).to eq(@icsp_key)
      end

      it 'completes delete request with correct parameters' do
        resp = @instance.instance_eval { rest_api(:icsp, :delete, '/', {}) }
        expect(resp['method']).to eq('DELETE')
        expect(resp['message']).to eq('Fake ICsp works!')
        expect(resp['content_type']).to eq('application/json')
        expect(resp['api_version']).to eq(@instance.instance_variable_get('@icsp_api_version'))
        expect(resp['auth']).to eq(@icsp_key)
      end

      it 'returns 404 error for invalid get request' do
        resp = @instance.instance_eval { rest_api(:icsp, :get, '/invalid_path', {}) }
        expect(resp['errorCode']).to eq('GENERIC_HTTP_404')
      end
    end

    it 'only accepts oneview or icsp hosts parameter' do
      expect { @instance.instance_eval { rest_api(:invalid, :get, '/', {}) } }.to raise_error(/Invalid rest host/)
    end

    it 'only accepts rest action parameters' do
      expect { @instance.instance_eval { rest_api(:oneview, :invalid, '/', {}) } }.to raise_error(/Invalid rest call/)
    end

  end

  describe 'get api versions' do

    it 'can parse the oneview api version' do
      expect(@instance.instance_eval { get_oneview_api_version }).to match(120)
    end

    it 'can parse the icsp api version' do
      expect(@instance.instance_eval { get_icsp_api_version }).to match(102)
    end
  end

end
