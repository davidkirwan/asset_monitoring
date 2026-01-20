# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe Asset::Monitoring do
  include Rack::Test::Methods

  def app
    Asset::Monitoring
  end

  describe 'GET /metrics' do
    context 'when all services are working' do
      around do |example|
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') do
            example.run
          end
        end
      end

      it 'returns 200 with prometheus format metrics' do
        get '/metrics'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('text/plain')
        expect(last_response.body).to include('# HELP', '# TYPE')
      end

      it 'includes bullionvault and coinbase metrics' do
        get '/metrics'
        expect(last_response.body).to include('bullion_gold_', 'bullion_silver_')
        expect(last_response.body).to include('crypto_btc_', 'crypto_eth_')
      end
    end

    context 'when bullionvault service fails' do
      it 'returns 500 status' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 500, body: 'Internal Server Error')

        get '/metrics'
        expect(last_response.status).to eq(500)
      end
    end

    context 'when coinbase service fails' do
      it 'returns 500 status' do
        stub_request(:get, 'https://api.coinbase.com/v2/prices/BTC-USD/spot')
          .to_return(status: 500, body: 'Internal Server Error')

        get '/metrics'
        expect(last_response.status).to eq(500)
      end
    end
  end

  describe 'GET /health' do
    it 'returns 200 with healthy JSON status' do
      get '/health'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('application/json')
      expect(JSON.parse(last_response.body)).to include('status' => 'healthy')
    end
  end

  describe 'GET /ready' do
    it 'returns 200 with ready JSON status' do
      get '/ready'
      expect(last_response.status).to eq(200)
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
