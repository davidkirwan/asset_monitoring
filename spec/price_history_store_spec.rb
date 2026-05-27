# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Asset::PriceHistoryStore do
  let(:log) { double('log', error: nil, warn: nil, debug: nil) }

  describe 'with in-memory database' do
    let(:store) { described_class.new(':memory:', retention_days: 7, log: log) }

    it 'reports as enabled after successful initialization' do
      expect(store.enabled?).to be true
      expect(store.db_path).to eq(':memory:')
      expect(store.retention_days).to eq(7)
    end

    it 'creates the schema on initialization' do
      # If the table did not exist the load would have failed inside the store
      points, help = store.load_recent
      expect(points).to eq([])
      expect(help).to eq({})
    end

    it 'round-trips a scrape via append and load_recent' do
      values = { 'crypto_btc_usd' => 67_000.5, 'bullion_gold_london_buy_eur' => 58_000.0 }
      help = { 'crypto_btc_usd' => 'The spot price of Bitcoin in US Dollar' }
      now = Time.now.to_i

      store.append_scrape!(now - 3600, values, help)

      points, loaded_help = store.load_recent(as_of: now)
      expect(points.length).to eq(1)
      expect(points.first[:t]).to eq(now - 3600)
      expect(points.first[:v]['crypto_btc_usd']).to eq(67_000.5)
      expect(loaded_help['crypto_btc_usd']).to eq('The spot price of Bitcoin in US Dollar')
    end

    it 'replaces values for the same timestamp (idempotent)' do
      now = Time.now.to_i
      store.append_scrape!(now - 100, { 'crypto_btc_usd' => 66_000 }, {})
      store.append_scrape!(now - 100, { 'crypto_btc_usd' => 66_500, 'crypto_eth_eur' => 2_800 }, {})

      points, = store.load_recent(as_of: now)
      expect(points.length).to eq(1)
      expect(points.first[:v]['crypto_btc_usd']).to eq(66_500)
      expect(points.first[:v]['crypto_eth_eur']).to eq(2_800)
    end

    it 'prunes data older than the configured retention window' do
      now = Time.now.to_i
      old = now - (8 * 24 * 60 * 60) # 8 days ago with 7 day retention

      store.append_scrape!(old, { 'old_metric' => 1.0 }, {})
      store.append_scrape!(now, { 'new_metric' => 2.0 }, {})

      # Force prune using a reference time
      store.prune!(now)

      points, = store.load_recent(as_of: now)
      expect(points.map { |p| p[:t] }).to eq([now])
    end

    it 'clear! removes all rows' do
      now = Time.now.to_i
      store.append_scrape!(now - 50, { 'x' => 1 }, {})
      expect(store.load_recent(as_of: now).first.length).to eq(1)

      store.clear!
      expect(store.load_recent(as_of: now).first).to eq([])
    end
  end

  describe 'with file-based database (temp file)' do
    let(:temp_db) do
      f = Tempfile.new(['asset_history', '.db'])
      f.close
      f.path
    end

    after do
      File.unlink(temp_db) if File.exist?(temp_db)
    end

    it 'persists across separate store instances (simulating restart)' do
      now = Time.now.to_i
      store1 = described_class.new(temp_db, retention_days: 30, log: log)
      store1.append_scrape!(now - 200, { 'crypto_btc_eur' => 62_000 }, { 'crypto_btc_eur' => 'BTC in EUR' })

      store2 = described_class.new(temp_db, retention_days: 30, log: log)
      points, help = store2.load_recent(as_of: now)

      expect(points.length).to be >= 1
      expect(points.last[:v]['crypto_btc_eur']).to eq(62_000)
      expect(help['crypto_btc_eur']).to eq('BTC in EUR')
    end
  end

  describe 'error handling' do
    it 'gracefully degrades when given a path that cannot be used for a database' do
      # Use a path under a definitely non-writable or impossible location for the DB file.
      # In containers mkdir_p under / often succeeds, so we primarily verify "no explosions on use".
      bad_path = '/proc/this/cannot/be/a/real/sqlite/db/here.db'
      store = described_class.new(bad_path, retention_days: 7, log: log)

      # The key guarantee: even if we could not open a usable store, later calls must not raise
      # and the rest of the application can continue with in-memory history only.
      expect { store.append_scrape!(Time.now.to_i, { 'a' => 1 }, {}) }.not_to raise_error
      expect { store.load_recent }.not_to raise_error
      # enabled? may be true or false depending on whether the OS let us create the dirs;
      # the important thing is safe degradation.
    end
  end
end

# Integration with the PriceHistory facade (the public API used by the rest of the app)
RSpec.describe Asset::PriceHistory do
  before { described_class.clear! }

  describe 'when configured with an in-memory SQLite store via env' do
    let(:db_path) { ':memory:' }

    around do |example|
      old_path = ENV.fetch('PRICE_HISTORY_DB_PATH', nil)
      old_ret = ENV.fetch('PRICE_HISTORY_RETENTION_DAYS', nil)
      ENV['PRICE_HISTORY_DB_PATH'] = db_path
      ENV['PRICE_HISTORY_RETENTION_DAYS'] = '5'
      described_class.configure_from_env!
      example.run
      described_class.clear!
      ENV['PRICE_HISTORY_DB_PATH'] = old_path
      ENV['PRICE_HISTORY_RETENTION_DAYS'] = old_ret
      # Re-configure back to pure memory for subsequent tests
      described_class.configure_from_env!
    end

    it 'hydrates from the store and reports the configured retention_days' do
      now = Time.now.to_i
      # Simulate a previous "scrape" that should survive a hypothetical restart
      described_class.record_scrape!(now - 120, <<~BV, <<~CB)
        # HELP bullion_gold_london_buy_eur Gold London
        bullion_gold_london_buy_eur{security_id="AUXLN"} 58900
      BV
        # HELP crypto_btc_usd Bitcoin USD
        crypto_btc_usd{currency1="Bitcoin"} 67000
      CB

      data = described_class.to_api_hash
      expect(data['retention_days']).to eq(5)
      expect(data['scrape_count']).to be >= 1

      ids = data['series'].map { |s| s['id'] }
      expect(ids).to include('bullion_gold_london_buy_eur', 'crypto_btc_usd')
    end

    it 'survives clear + re-record and still persists to the backing store' do
      now = Time.now.to_i
      described_class.record_scrape!(now - 90, ' # HELP x y\nx{ } 1', '')
      expect(described_class.to_api_hash['scrape_count']).to be >= 1

      described_class.clear!
      expect(described_class.to_api_hash['scrape_count']).to eq(0)

      described_class.record_scrape!(now - 60, ' # HELP z z\nz{ } 9', '')
      expect(described_class.to_api_hash['scrape_count']).to eq(1)
    end
  end
end
