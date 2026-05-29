# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe Asset::Monitoring do
  include Rack::Test::Methods

  def app
    Asset::Monitoring
  end

  describe 'GET /metrics' do
    before { Asset::MetricsCache.reset! }

    context 'when all services are working' do
      around do |example|
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') do
            example.run
          end
        end
      end

      def refresh_cache
        Asset::MetricsCache.refresh_silent!(app.settings)
      end

      it 'returns 200 with prometheus format metrics' do
        refresh_cache
        get '/metrics'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('text/plain')
        expect(last_response.body).to include('# HELP', '# TYPE')
      end

      it 'includes bullionvault and coinbase metrics' do
        refresh_cache
        get '/metrics'
        expect(last_response.body).to include('bullion_gold_', 'bullion_silver_')
        expect(last_response.body).to include('crypto_btc_', 'crypto_eth_')
      end
    end

    context 'when bullionvault service fails' do
      it 'returns 500 status when cache is empty' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 500, body: 'Internal Server Error')

        Asset::MetricsCache.refresh_silent!(app.settings)
        get '/metrics'
        expect(last_response.status).to eq(500)
      end
    end

    context 'when coinbase service fails' do
      let(:minimal_bullionvault_xml) do
        <<~XML
          <?xml version="1.0"?>
          <envelope>
            <message>
              <market>
                <pitches>
                  <pitch securityId="AUXZU" considerationCurrency="usd">
                    <buyPrices><price actionIndicator="B" quantity="0.1" limit="200000"/></buyPrices>
                    <sellPrices><price actionIndicator="S" quantity="0.1" limit="201000"/></sellPrices>
                  </pitch>
                </pitches>
              </market>
            </message>
          </envelope>
        XML
      end

      it 'returns 500 status when cache is empty' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 200, body: minimal_bullionvault_xml, headers: { 'Content-Type' => 'text/xml' })
        stub_request(:get, 'https://api.coinbase.com/v2/prices/BTC-USD/spot')
          .to_return(status: 500, body: 'Internal Server Error')

        Asset::MetricsCache.refresh_silent!(app.settings)
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

  describe 'GET /' do
    it 'redirects to /portfolio' do
      get '/'
      expect(last_response.status).to eq(302)
      expect(last_response['Location']).to end_with('/portfolio')
    end
  end

  describe 'GET /portfolio' do
    it 'returns 200 and HTML' do
      get '/portfolio'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Portfolio', 'Gold', 'Bitcoin', 'Cash', 'Property', 'Save portfolio',
                                            'Portfolio history', 'chart.js')
    end
  end

  describe 'GET /dashboard' do
    it 'returns 200 and HTML' do
      get '/dashboard'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Dashboard', 'chart.js', '1 day', '1 month', '1 year')
    end
  end

  describe 'GET /api/spot_prices.json' do
    before { Asset::MetricsCache.reset! }

    it 'returns JSON with price buckets' do
      get '/api/spot_prices.json'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to include('prices', 'units', 'updated_at')
    end
  end

  describe 'portfolio API' do
    around do |example|
      old = ENV.fetch('PORTFOLIO_DB_PATH', nil)
      ENV['PORTFOLIO_DB_PATH'] = ':memory:'
      Asset::Portfolio.configure_from_env!(root: app.settings.root)
      example.run
      ENV['PORTFOLIO_DB_PATH'] = old
      Asset::Portfolio.configure_from_env!(root: app.settings.root)
    end

    it 'returns default portfolio JSON' do
      get '/api/portfolio.json'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['summary_currency']).to eq('EUR')
      expect(data['holdings']['platinum']['unit']).to eq('troy_oz')
      expect(data['holdings']['pension']['unit']).to eq('eur')
      expect(data['holdings']['stocks']['unit']).to eq('eur')
      expect(data['persisted']).to be true
    end

    it 'saves portfolio holdings via PUT' do
      payload = {
        summary_currency: 'USD',
        holdings: {
          stocks: { amount: '45000', unit: 'usd' },
          cash: { amount: '1000', unit: 'eur' }
        }
      }

      put '/api/portfolio.json', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result['ok']).to be true
      expect(result['portfolio']['holdings']['stocks']).to include('amount' => '45000', 'unit' => 'usd')

      get '/api/portfolio.json'
      data = JSON.parse(last_response.body)
      expect(data['summary_currency']).to eq('USD')
      expect(data['holdings']['stocks']['amount']).to eq('45000')
    end

    it 'returns portfolio history JSON' do
      get '/api/portfolio_history.json'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to include('retention_days', 'snapshot_count', 'assets', 'totals', 'currencies')
      expect(data['currencies']).to eq(%w[eur usd gbp jpy])
    end

    it 'records a snapshot when portfolio is saved with spot prices available' do
      VCR.use_cassette('bullionvault_success') do
        VCR.use_cassette('coinbase_success') do
          Asset::MetricsCache.refresh_silent!(app.settings)
          put '/api/portfolio.json',
              { summary_currency: 'EUR', holdings: { gold: { amount: '100', unit: 'grams' } } }.to_json,
              { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      get '/api/portfolio_history.json'
      data = JSON.parse(last_response.body)
      expect(data['snapshot_count']).to be >= 1
      gold = data['assets'].find { |a| a['id'] == 'gold' }
      expect(gold['values']).not_to be_empty
    end
  end

  describe 'GET /api/price_history.json' do
    before { Asset::MetricsCache.reset! }

    it 'returns JSON with series' do
      get '/api/price_history.json'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data).to include('retention_days' => 7, 'scrape_count' => 0, 'series' => [])
    end

    context 'with cached scrapes' do
      around do |example|
        VCR.use_cassette('bullionvault_success') do
          VCR.use_cassette('coinbase_success') { example.run }
        end
      end

      it 'includes parsed series' do
        Asset::MetricsCache.refresh_silent!(app.settings)
        get '/api/price_history.json'
        data = JSON.parse(last_response.body)
        expect(data['scrape_count']).to be >= 1
        ids = data['series'].map { |s| s['id'] }
        expect(ids.any? { |id| id.include?('crypto_btc') }).to be true
      end
    end
  end

  describe 'GET /unknown' do
    it 'returns 404 status' do
      get '/unknown'
      expect(last_response.status).to eq(404)
    end
  end
end
