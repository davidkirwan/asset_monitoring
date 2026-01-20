# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Coinbase do
  describe '.spot' do
    let(:logger) { instance_double(Logger, debug: nil) }
    let(:settings) { instance_double(Asset::Monitoring, log: logger) }

    context 'with successful API response', vcr: { cassette_name: 'coinbase_success' } do
      subject(:result) { described_class.spot(settings) }

      it 'returns prometheus formatted metrics' do
        expect(result).to include('# HELP', '# TYPE', 'crypto_btc_', 'crypto_eth_')
      end

      it 'includes Bitcoin and Ethereum prices in USD and EUR' do
        expect(result).to include('crypto_btc_usd', 'crypto_btc_eur', 'crypto_eth_usd', 'crypto_eth_eur')
      end

      it 'includes proper labels' do
        expect(result).to include('currency1="Bitcoin"', 'currency1="Ethereum"', 'exchange="Coinbase"')
      end
    end

    context 'with API failure' do
      it 'raises an exception' do
        stub_request(:get, 'https://api.coinbase.com/v2/prices/BTC-USD/spot')
          .to_return(status: 500, body: 'Internal Server Error')

        expect { described_class.spot(settings) }.to raise_error(StandardError)
      end
    end

    context 'with invalid JSON response' do
      it 'raises an exception' do
        stub_request(:get, 'https://api.coinbase.com/v2/prices/BTC-USD/spot')
          .to_return(status: 200, body: 'invalid json')

        expect { described_class.spot(settings) }.to raise_error(StandardError)
      end
    end
  end
end
