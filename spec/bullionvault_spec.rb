require 'spec_helper'

RSpec.describe BullionVault do
  describe '.spot' do
    let(:settings) { double('settings', log: double('logger', debug: nil)) }

    context 'with successful API response' do
      it 'returns prometheus formatted metrics' do
        VCR.use_cassette('bullionvault_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('# HELP')
          expect(result).to include('# TYPE')
          expect(result).to include('bullion_gold_')
          expect(result).to include('bullion_silver_')
        end
      end

      it 'includes all expected exchanges' do
        VCR.use_cassette('bullionvault_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('Zurich')
          expect(result).to include('London')
          expect(result).to include('New York')
          expect(result).to include('Toronto')
          expect(result).to include('Singapore')
        end
      end

      it 'includes all expected metals' do
        VCR.use_cassette('bullionvault_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('Gold')
          expect(result).to include('Silver')
          expect(result).to include('Platinum')
        end
      end

      it 'includes buy and sell prices' do
        VCR.use_cassette('bullionvault_success') do
          result = described_class.spot(settings)
          
          expect(result).to include('buy_')
          expect(result).to include('sell_')
        end
      end
    end

    context 'with API failure' do
      it 'raises an exception' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 500, body: 'Internal Server Error')

        expect { described_class.spot(settings) }.to raise_error(StandardError)
      end
    end

    context 'with invalid XML response' do
      it 'handles parsing errors gracefully' do
        stub_request(:get, 'https://www.bullionvault.com/view_market_xml.do')
          .to_return(status: 200, body: '<invalid>xml</invalid>')

        expect { described_class.spot(settings) }.to raise_error(StandardError)
      end
    end
  end
end