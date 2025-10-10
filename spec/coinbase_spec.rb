require 'spec_helper'

RSpec.describe Coinbase do
  describe '.spot' do
    let(:settings) { double('settings', log: double('logger', debug: nil)) }

    context 'with successful API response' do
      it 'returns prometheus formatted metrics' do
        VCR.use_cassette('coinbase_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('# HELP')
          expect(result).to include('# TYPE')
          expect(result).to include('crypto_btc_')
          expect(result).to include('crypto_eth_')
        end
      end

      it 'includes Bitcoin prices in USD and EUR' do
        VCR.use_cassette('coinbase_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('crypto_btc_usd')
          expect(result).to include('crypto_btc_eur')
        end
      end

      it 'includes Ethereum prices in USD and EUR' do
        VCR.use_cassette('coinbase_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('crypto_eth_usd')
          expect(result).to include('crypto_eth_eur')
        end
      end

      it 'includes proper labels' do
        VCR.use_cassette('coinbase_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('currency1="Bitcoin"')
          expect(result).to include('currency1="Ethereum"')
          expect(result).to include('exchange="Coinbase"')
        end
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
      it 'handles parsing errors gracefully' do
        stub_request(:get, 'https://api.coinbase.com/v2/prices/BTC-USD/spot')
          .to_return(status: 200, body: 'invalid json')

        expect { described_class.spot(settings) }.to raise_error(StandardError)
      end
    end
  end
end