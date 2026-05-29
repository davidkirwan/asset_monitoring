# frozen_string_literal: true

require 'spec_helper'
require 'portfolio_valuation'

RSpec.describe Asset::PortfolioValuation do
  describe '.compute and .totals' do
    it 'values commodity, crypto, and cash holdings in all fiat currencies' do
      spot = {
        'gold' => { 'eur' => 100.0, 'usd' => 110.0, 'gbp' => 90.0, 'jpy' => 15_000.0 },
        'bitcoin' => { 'eur' => 50_000.0, 'usd' => 55_000.0 }
      }
      holdings = {
        'gold' => { 'amount' => '64.301', 'unit' => 'grams' },
        'bitcoin' => { 'amount' => '0.5', 'unit' => 'btc' },
        'cash' => { 'amount' => '1000', 'unit' => 'eur' }
      }

      valuations = described_class.compute(holdings, spot)
      totals = described_class.totals(valuations)

      expect(valuations['gold']['eur']['quantity']).to be_within(0.001).of(0.1)
      expect(valuations['gold']['eur']['value']).to be_within(0.01).of(10.0)
      expect(valuations['bitcoin']['usd']['value']).to eq(27_500.0)
      expect(valuations['cash']['eur']['value']).to eq(1000.0)
      expect(valuations['cash']['usd']['value']).to eq(1100.0)
      expect(totals['eur']).to be_within(0.01).of(26_010.0)
      expect(totals['usd']).to be_within(0.01).of(28_611.0)
    end

    it 'converts stocks and property using FX cross-rates' do
      spot = {
        'gold' => { 'eur' => 100.0, 'usd' => 110.0, 'gbp' => 90.0, 'jpy' => 15_000.0 }
      }
      holdings = {
        'stocks' => { 'amount' => '45000', 'unit' => 'usd' },
        'property' => { 'amount' => '900', 'unit' => 'gbp' }
      }

      valuations = described_class.compute(holdings, spot)

      expect(valuations['stocks']['eur']['value']).to be_within(0.01).of(40_909.09)
      expect(valuations['property']['jpy']['value']).to be_within(1.0).of(150_000.0)
    end

    it 'converts pension using FX cross-rates' do
      spot = {
        'gold' => { 'eur' => 100.0, 'usd' => 110.0, 'gbp' => 90.0, 'jpy' => 15_000.0 }
      }
      holdings = { 'pension' => { 'amount' => '100000', 'unit' => 'eur' } }

      valuations = described_class.compute(holdings, spot)

      expect(valuations['pension']['eur']['value']).to eq(100_000.0)
      expect(valuations['pension']['usd']['value']).to be_within(0.01).of(110_000.0)
    end

    it 'values platinum holdings like other metals' do
      spot = { 'platinum' => { 'eur' => 30_000.0, 'usd' => 33_000.0 } }
      holdings = { 'platinum' => { 'amount' => '1', 'unit' => 'troy_oz' } }

      valuations = described_class.compute(holdings, spot)
      kg = 1 * described_class::TROY_OZ_TO_KG

      expect(valuations['platinum']['eur']['quantity']).to be_within(0.0001).of(kg)
      expect(valuations['platinum']['eur']['value']).to be_within(0.01).of(kg * 30_000.0)
      expect(valuations['platinum']['usd']['value']).to be_within(0.01).of(kg * 33_000.0)
    end
  end
end
