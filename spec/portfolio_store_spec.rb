# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'logger'

RSpec.describe Asset::PortfolioStore do
  let(:log) { instance_double(Logger, error: nil, warn: nil, info: nil, debug: nil) }

  describe 'with in-memory database' do
    let(:store) { described_class.new(':memory:', log: log) }
    let(:portfolio_payload) do
      {
        'summary_currency' => 'USD',
        'holdings' => {
          'gold' => { 'amount' => '12', 'unit' => 'grams' },
          'silver' => { 'amount' => '5', 'unit' => 'troy_oz' },
          'platinum' => { 'amount' => '2', 'unit' => 'troy_oz' },
          'bitcoin' => { 'amount' => '25000000', 'unit' => 'satoshis' },
          'ethereum' => { 'amount' => '3.5', 'unit' => 'eth' },
          'stocks' => { 'amount' => '120000', 'unit' => 'usd' },
          'cash' => { 'amount' => '5000', 'unit' => 'eur' },
          'property' => { 'amount' => '350000', 'unit' => 'gbp' },
          'pension' => { 'amount' => '250000', 'unit' => 'eur' }
        }
      }
    end
    let(:history_valuations) do
      {
        'gold' => {
          'eur' => { 'quantity' => 0.1, 'value' => 100.0 },
          'usd' => { 'quantity' => 0.1, 'value' => 110.0 }
        },
        'cash' => {
          'eur' => { 'quantity' => 500.0, 'value' => 500.0 }
        }
      }
    end

    it 'reports as enabled after successful initialization' do
      expect(store.enabled?).to be true
    end

    it 'returns defaults before anything is saved' do
      data = store.load
      expect(data['summary_currency']).to eq('EUR')
      expect(data['holdings']['gold']).to eq('amount' => '', 'unit' => 'troy_oz')
      expect(data['holdings']['platinum']).to eq('amount' => '', 'unit' => 'troy_oz')
      expect(data['holdings']['pension']).to eq('amount' => '', 'unit' => 'eur')
      expect(data['holdings']['stocks']).to eq('amount' => '', 'unit' => 'eur')
    end

    it 'saves and reloads portfolio holdings' do
      expect(store.save!(portfolio_payload)).to be true
      expect(store.load).to include(
        'summary_currency' => 'USD',
        'holdings' => include(
          'stocks' => { 'amount' => '120000', 'unit' => 'usd' },
          'pension' => { 'amount' => '250000', 'unit' => 'eur' }
        ),
        'updated_at' => kind_of(String)
      )
    end

    it 'records and loads portfolio history snapshots' do
      expect(store.record_snapshot!(Time.now.to_i, history_valuations, totals: { 'eur' => 600.0, 'usd' => 110.0 })).to be true
      history = store.load_history
      recorded_at = history['totals']['eur'].first.first
      expect(history['snapshot_count']).to eq(1)
      expect(history['assets'].find { |a| a['id'] == 'gold' }['values']['usd']).to eq([[recorded_at, 110.0]])
    end

    it 'normalizes invalid units to defaults' do
      store.save!(
        'summary_currency' => 'EUR',
        'holdings' => {
          'stocks' => { 'amount' => '1', 'unit' => 'shares' },
          'gold' => { 'amount' => '2', 'unit' => 'invalid' }
        }
      )

      loaded = store.load
      expect(loaded['holdings']['stocks']['unit']).to eq('eur')
      expect(loaded['holdings']['gold']['unit']).to eq('troy_oz')
    end
  end

  describe 'with file-based database' do
    let(:temp_db) do
      dir = Dir.mktmpdir
      File.join(dir, 'portfolio.db')
    end

    after do
      FileUtils.remove_entry(File.dirname(temp_db)) if temp_db && Dir.exist?(File.dirname(temp_db))
    end

    it 'persists across separate store instances' do
      store1 = described_class.new(temp_db, log: log)
      store1.save!(
        'summary_currency' => 'GBP',
        'holdings' => { 'cash' => { 'amount' => '999', 'unit' => 'gbp' } }
      )

      store2 = described_class.new(temp_db, log: log)
      loaded = store2.load
      expect(loaded['summary_currency']).to eq('GBP')
      expect(loaded['holdings']['cash']).to eq('amount' => '999', 'unit' => 'gbp')
    end
  end
end
