require 'spec_helper'
require 'rack/test'

RSpec.describe Asset::Monitoring do
  include Rack::Test::Methods

  def app
    Asset::Monitoring
  end

  describe 'GET /metrics' do
    context 'when all services are working' do
      it 'returns 200 status' do
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') do
            get '/metrics'
            expect(last_response.status).to eq(200)
          end
        end
      end

      it 'returns prometheus format metrics' do
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') do
            get '/metrics'
            expect(last_response.content_type).to include('text/plain')
            expect(last_response.body).to include('# HELP')
            expect(last_response.body).to include('# TYPE')
          end
        end
      end

      it 'includes bullionvault metrics' do
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') do
            get '/metrics'
            expect(last_response.body).to include('bullion_gold_')
            expect(last_response.body).to include('bullion_silver_')
          end
        end
      end

      it 'includes coinbase metrics' do
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') do
            get '/metrics'
            expect(last_response.body).to include('crypto_btc_')
            expect(last_response.body).to include('crypto_eth_')
          end
        end
      end
    end

    context 'when bullionvault service fails' do
      it 'returns 500 status' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 500, body: 'Internal Server Error')

        VCR.use_cassette('coinbase_success') do
          get '/metrics'
          expect(last_response.status).to eq(500)
        end
      end
    end

    context 'when coinbase service fails' do
      it 'returns 500 status' do
        VCR.use_cassette('bullionvault_success') do
          stub_request(:get, 'https://api.coinbase.com/v2/prices/BTC-USD/spot')
            .to_return(status: 500, body: 'Internal Server Error')

          get '/metrics'
          expect(last_response.status).to eq(500)
        end
      end
    end
  end

  describe 'GET /health' do
    it 'returns 200 status' do
      get '/health'
      expect(last_response.status).to eq(200)
    end

    it 'returns JSON health status' do
      get '/health'
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('status' => 'healthy')
    end
  end

  describe 'GET /ready' do
    it 'returns 200 status' do
      get '/ready'
      expect(last_response.status).to eq(200)
    end

    it 'returns JSON readiness status' do
      get '/ready'
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('status' => 'ready')
    end
  end

  describe 'GET /unknown' do
    it 'returns 404 status' do
      get '/unknown'
      expect(last_response.status).to eq(404)
    end
  end
end