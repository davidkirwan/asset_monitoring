# frozen_string_literal: true

require 'spec_helper'
require 'fx_rates'

RSpec.describe Asset::FxRates do
  describe '.from_prices' do
    it 'uses gold quotes when at least two fiat prices are available' do
      prices = {
        'gold' => { 'eur' => 100.0, 'usd' => 110.0, 'gbp' => 90.0 },
        'silver' => { 'eur' => 2.0 }
      }

      expect(described_class.from_prices(prices)).to eq(
        'eur' => 100.0,
        'usd' => 110.0,
        'gbp' => 90.0
      )
    end

    it 'falls back to silver when gold is unavailable' do
      prices = { 'silver' => { 'eur' => 2.0, 'usd' => 2.2 } }

      expect(described_class.from_prices(prices)).to eq('eur' => 2.0, 'usd' => 2.2)
    end
  end

  describe '.convert' do
    let(:quotes) { { 'eur' => 100.0, 'usd' => 110.0, 'gbp' => 90.0, 'jpy' => 15_000.0 } }

    it 'converts between currencies using commodity cross-rates' do
      expect(described_class.convert(1000, 'eur', 'usd', quotes)).to eq(1100.0)
      expect(described_class.convert(1100, 'usd', 'eur', quotes)).to eq(1000.0)
    end

    it 'returns the same amount for identical currencies' do
      expect(described_class.convert(500, 'gbp', 'gbp', quotes)).to eq(500.0)
    end
  end

  describe '.fiat_values' do
    let(:quotes) { { 'eur' => 100.0, 'usd' => 110.0, 'gbp' => 90.0, 'jpy' => 15_000.0 } }

    it 'fills all currencies when FX quotes are available' do
      values = described_class.fiat_values(1000, 'eur', quotes)

      expect(values['eur']['value']).to eq(1000.0)
      expect(values['usd']['value']).to eq(1100.0)
      expect(values['gbp']['value']).to eq(900.0)
      expect(values['jpy']['value']).to eq(150_000.0)
    end

    it 'falls back to native currency only when FX quotes are missing' do
      values = described_class.fiat_values(1000, 'eur', nil)

      expect(values['eur']['value']).to eq(1000.0)
      expect(values['usd']).to be_nil
    end
  end
end
