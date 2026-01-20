# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BullionVault do
  describe '.spot' do
    let(:logger) { instance_double(Logger, debug: nil, warn: nil) }
    let(:settings) { instance_double(Asset::Monitoring, log: logger) }

    context 'with successful API response', vcr: { cassette_name: 'bullionvault_success' } do
      subject(:result) { described_class.spot(settings) }

      it 'returns prometheus formatted metrics' do
        expect(result).to include('# HELP', '# TYPE', 'bullion_gold_', 'bullion_silver_')
      end

      it 'includes all expected exchanges' do
        expect(result).to include('Zurich', 'London', 'New York', 'Toronto', 'Singapore')
      end

      it 'includes all expected metals' do
        expect(result).to include('Gold', 'Silver', 'Platinum')
      end

      it 'includes buy and sell prices' do
        expect(result).to include('buy_', 'sell_')
      end
    end

    context 'with API failure' do
      it 'raises an exception' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 500, body: 'Internal Server Error')

        expect { described_class.spot(settings) }.to raise_error(StandardError)
      end
    end

    context 'with invalid XML structure' do
      it 'raises an exception' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 200, body: '<invalid>xml</invalid>')

        expect { described_class.spot(settings) }.to raise_error(StandardError, /no pitch data/)
      end
    end
  end
end
