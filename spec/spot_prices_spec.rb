# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Asset::SpotPrices do
  before { Asset::MetricsCache.reset! }

  it 'returns empty prices when cache is empty' do
    data = described_class.to_api_hash
    expect(data['prices']).to eq({})
    expect(data['last_scrape_epoch']).to eq(0)
  end

  context 'with cached scrapes' do
    around do |example|
      VCR.use_cassette('bullionvault_success') do
        VCR.use_cassette('coinbase_success') { example.run }
      end
    end

    it 'includes structured metal and crypto prices' do
      Asset::MetricsCache.refresh_silent!(Asset::Monitoring.settings)
      data = described_class.to_api_hash

      expect(data['prices']['gold']).to include('eur')
      expect(data['prices']['silver']).to include('usd')
      expect(data['prices']['platinum']).to include('eur')
      expect(data['prices']['bitcoin']).to include('usd')
      expect(data['prices']['ethereum']).to include('eur')
      expect(data['units']).to include('gold' => 'per_kg', 'bitcoin' => 'per_coin')
      expect(data['fx_quotes']).to include('eur', 'usd')
    end
  end
end
