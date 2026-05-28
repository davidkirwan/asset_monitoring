# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'

require_relative 'portfolio_constants'

module Asset
  # SQLite-backed portfolio holdings (one row per asset category).
  class PortfolioStore
    ASSET_IDS = PortfolioConstants::ASSET_IDS
    UNITS = PortfolioConstants::UNITS
    SUMMARY_CURRENCIES = PortfolioConstants::SUMMARY_CURRENCIES

    attr_reader :db_path

    def initialize(db_path, log: nil)
      @db_path = db_path.to_s
      @log = log
      @db = nil
      ensure_directory
      open_database
      ensure_schema
      log_info("Opened portfolio store at #{@db_path}")
    rescue StandardError => e
      log_error("Failed to initialize portfolio store at #{@db_path}: #{e.class}: #{e.message}")
      close_database
      @db = nil
    end

    def enabled?
      !@db.nil?
    end

    def load
      return default_payload unless enabled?

      summary_currency = fetch_setting('summary_currency') || 'EUR'
      holdings = ASSET_IDS.to_h do |asset_id|
        row = @db.get_first_row('SELECT amount, unit FROM portfolio_holdings WHERE asset_id = ?', [asset_id])
        if row
          [asset_id, { 'amount' => row[0].to_s, 'unit' => row[1].to_s }]
        else
          [asset_id, default_holding(asset_id)]
        end
      end

      {
        'summary_currency' => summary_currency,
        'holdings' => holdings,
        'updated_at' => fetch_setting('updated_at'),
        'persisted' => true
      }
    rescue StandardError => e
      log_error("Failed to load portfolio: #{e.message}")
      default_payload.merge('persisted' => false, 'error' => e.message)
    end

    def save!(payload)
      return false unless enabled?

      summary_currency = normalize_summary_currency(payload['summary_currency'] || payload[:summary_currency])
      holdings = normalize_holdings(payload['holdings'] || payload[:holdings])
      now = Time.now.utc.iso8601(3)

      @db.transaction do
        upsert_setting('summary_currency', summary_currency)
        upsert_setting('updated_at', now)
        ASSET_IDS.each do |asset_id|
          holding = holdings[asset_id]
          @db.execute(<<~SQL, [asset_id, holding['amount'], holding['unit'], now])
            INSERT INTO portfolio_holdings (asset_id, amount, unit, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(asset_id) DO UPDATE SET
              amount = excluded.amount,
              unit = excluded.unit,
              updated_at = excluded.updated_at
          SQL
        end
      end

      true
    rescue StandardError => e
      log_error("Failed to save portfolio: #{e.message}")
      false
    end

    def record_snapshot!(recorded_at, valuations, totals: {})
      return false unless enabled?

      epoch = recorded_at.to_i
      @db.transaction do
        valuations.each do |asset_id, currencies|
          currencies.each do |currency, data|
            next unless data

            @db.execute(<<~SQL, [epoch, asset_id, currency, data['quantity'], data['value']])
              INSERT INTO portfolio_history (recorded_at, asset_id, currency, quantity, value)
              VALUES (?, ?, ?, ?, ?)
              ON CONFLICT(recorded_at, asset_id, currency) DO UPDATE SET
                quantity = excluded.quantity,
                value = excluded.value
            SQL
          end
        end

        totals.each do |currency, value|
          next if value.nil?

          @db.execute(<<~SQL, [epoch, 'total', currency, nil, value])
            INSERT INTO portfolio_history (recorded_at, asset_id, currency, quantity, value)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(recorded_at, asset_id, currency) DO UPDATE SET
              quantity = excluded.quantity,
              value = excluded.value
          SQL
        end
      end

      prune_history!(epoch)
      true
    rescue StandardError => e
      log_error("Failed to record portfolio snapshot: #{e.message}")
      false
    end

    def load_history
      return empty_history unless enabled?

      cutoff = Time.now.to_i - (retention_days * 24 * 60 * 60)
      rows = @db.execute(<<~SQL, [cutoff])
        SELECT recorded_at, asset_id, currency, quantity, value
        FROM portfolio_history
        WHERE recorded_at >= ?
        ORDER BY recorded_at ASC, asset_id ASC, currency ASC
      SQL

      grouped = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
      timestamps = []
      rows.each do |recorded_at, asset_id, currency, quantity, value|
        timestamps << recorded_at
        grouped[asset_id][currency] << [recorded_at.to_i, value.to_f, quantity&.to_f]
      end

      assets = PortfolioStore::ASSET_IDS.map do |asset_id|
        {
          'id' => asset_id,
          'label' => PortfolioConstants::ASSET_LABELS[asset_id],
          'values' => grouped[asset_id].transform_values { |points| points.map { |t, v, _q| [t, v] } }
        }
      end

      {
        'retention_days' => retention_days,
        'snapshot_count' => timestamps.uniq.length,
        'updated_at' => Time.now.utc.iso8601(3),
        'currencies' => SUMMARY_CURRENCIES.map(&:downcase),
        'assets' => assets,
        'totals' => grouped['total'].transform_values { |points| points.map { |t, v, _q| [t, v] } }
      }
    rescue StandardError => e
      log_error("Failed to load portfolio history: #{e.message}")
      empty_history.merge('error' => e.message)
    end

    def close
      close_database
    end

    def self.default_holding(asset_id)
      PortfolioConstants.default_holding(asset_id)
    end

    def self.default_payload
      {
        'summary_currency' => 'EUR',
        'holdings' => ASSET_IDS.to_h { |id| [id, default_holding(id)] },
        'updated_at' => nil,
        'persisted' => false
      }
    end

    private

    def default_payload
      self.class.default_payload
    end

    def default_holding(asset_id)
      self.class.default_holding(asset_id)
    end

    def normalize_summary_currency(value)
      code = value.to_s.strip.upcase
      SUMMARY_CURRENCIES.include?(code) ? code : 'EUR'
    end

    def normalize_holdings(raw)
      input = raw.is_a?(Hash) ? raw : {}
      ASSET_IDS.to_h do |asset_id|
        holding = input[asset_id] || input[asset_id.to_sym] || default_holding(asset_id)
        amount = holding.is_a?(Hash) ? holding['amount'] || holding[:amount] : ''
        unit = holding.is_a?(Hash) ? holding['unit'] || holding[:unit] : default_holding(asset_id)['unit']
        unit = unit.to_s.downcase
        unit = default_holding(asset_id)['unit'] unless UNITS[asset_id].include?(unit)
        [asset_id, { 'amount' => amount.to_s, 'unit' => unit }]
      end
    end

    def fetch_setting(key)
      @db.get_first_value('SELECT value FROM portfolio_settings WHERE key = ?', [key])
    end

    def upsert_setting(key, value)
      @db.execute(<<~SQL, [key, value.to_s, Time.now.to_i])
        INSERT INTO portfolio_settings (key, value, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(key) DO UPDATE SET
          value = excluded.value,
          updated_at = excluded.updated_at
      SQL
    end

    def ensure_directory
      return if @db_path.empty? || @db_path == ':memory:'

      FileUtils.mkdir_p(File.dirname(@db_path))
    end

    def open_database
      return if @db_path.empty?

      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = false
      @db.busy_timeout = 5_000
      @db.execute('PRAGMA foreign_keys = ON')
    end

    def ensure_schema
      return unless @db

      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS portfolio_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      SQL

      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS portfolio_holdings (
          asset_id TEXT PRIMARY KEY,
          amount TEXT NOT NULL,
          unit TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      SQL

      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS portfolio_history (
          recorded_at INTEGER NOT NULL,
          asset_id TEXT NOT NULL,
          currency TEXT NOT NULL,
          quantity REAL,
          value REAL NOT NULL,
          PRIMARY KEY (recorded_at, asset_id, currency)
        )
      SQL

      @db.execute(<<~SQL)
        CREATE INDEX IF NOT EXISTS idx_portfolio_history_recorded_at
        ON portfolio_history (recorded_at)
      SQL
    end

    def retention_days
      val = ENV.fetch('PRICE_HISTORY_RETENTION_DAYS', '365').to_i
      val.positive? ? val : 365
    end

    def prune_history!(reference_time)
      cutoff = reference_time.to_i - (retention_days * 24 * 60 * 60)
      @db.execute('DELETE FROM portfolio_history WHERE recorded_at < ?', [cutoff])
    end

    def empty_history
      {
        'retention_days' => retention_days,
        'snapshot_count' => 0,
        'updated_at' => Time.now.utc.iso8601(3),
        'currencies' => SUMMARY_CURRENCIES.map(&:downcase),
        'assets' => PortfolioStore::ASSET_IDS.map do |asset_id|
          {
            'id' => asset_id,
            'label' => PortfolioConstants::ASSET_LABELS[asset_id],
            'values' => {}
          }
        end,
        'totals' => {}
      }
    end

    def close_database
      @db&.close
    rescue StandardError
      nil
    ensure
      @db = nil
    end

    def log_error(message)
      if @log.respond_to?(:error)
        @log.error(message)
      else
        warn "[PortfolioStore] #{message}"
      end
    end

    def log_info(message)
      if @log.respond_to?(:info)
        @log.info(message)
      else
        warn "[PortfolioStore] #{message}"
      end
    end
  end
end
