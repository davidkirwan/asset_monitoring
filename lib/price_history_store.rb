# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'

module Asset
  # rubocop:disable Metrics/ClassLength
  # Optional durable backing store for PriceHistory using SQLite.
  # When PRICE_HISTORY_DB_PATH is set, PriceHistory will use an instance of this class.
  # All methods are safe to call; errors are logged and swallowed so the app keeps running.
  class PriceHistoryStore
    SCHEMA_VERSION = 1

    attr_reader :db_path, :retention_days

    def initialize(db_path, retention_days:, log: nil)
      @db_path = db_path.to_s
      @retention_days = retention_days.to_i.positive? ? retention_days.to_i : 7
      @log = log
      @db = nil
      ensure_directory
      open_database
      ensure_schema
      log_info("Opened SQLite store at #{@db_path}")
    rescue StandardError => e
      log_error("Failed to initialize SQLite store at #{@db_path}: #{e.class}: #{e.message}")
      close_database
      @db = nil
    end

    def enabled?
      !@db.nil?
    end

    # Returns [points_array, help_hash] for recent scrapes within retention window.
    # Points are in ascending time order: [{ t: epoch, v: {metric_name => value, ...} }, ...]
    def load_recent(as_of: Time.now.to_i)
      return [[], {}] unless enabled?

      cutoff = as_of.to_i - (@retention_days * 24 * 60 * 60)
      points_by_time = {}
      help = {}

      @db.execute(<<~SQL, [cutoff]) do |row|
        SELECT scraped_at, metric_name, value, help_text
        FROM price_history
        WHERE scraped_at >= ?
        ORDER BY scraped_at ASC, metric_name ASC
      SQL
        accumulate_row!(points_by_time, help, row)
      end

      points = points_by_time.keys.sort.map { |t| { t: t, v: points_by_time[t] } }
      [points, help]
    rescue StandardError => e
      log_error("Failed to load recent history from SQLite: #{e.message}")
      [[], {}]
    end

    # Persist one scrape's parsed values + help. Uses INSERT OR REPLACE for idempotency.
    def append_scrape!(epoch, values, help)
      return false unless enabled? && epoch

      now = epoch.to_i
      @db.transaction do
        values.each do |metric_name, value|
          next if value.nil?

          h = help[metric_name]
          @db.execute(<<~SQL, [now, metric_name.to_s, value.to_f, h])
            INSERT OR REPLACE INTO price_history (scraped_at, metric_name, value, help_text)
            VALUES (?, ?, ?, ?)
          SQL
        end
      end

      prune!(now) # prune using the new scrape time as reference
      true
    rescue StandardError => e
      log_error("Failed to append scrape at #{epoch} to SQLite: #{e.message}")
      false
    end

    # Delete rows older than retention window.
    def prune!(reference_time = Time.now.to_i)
      return false unless enabled?

      cutoff = reference_time.to_i - (@retention_days * 24 * 60 * 60)
      @db.execute('DELETE FROM price_history WHERE scraped_at < ?', [cutoff])
      true
    rescue StandardError => e
      log_error("Failed to prune old rows from SQLite: #{e.message}")
      false
    end

    # Remove all rows (used by test helpers).
    def clear!
      return false unless enabled?

      @db.execute('DELETE FROM price_history')
      true
    rescue StandardError => e
      log_error("Failed to clear SQLite history: #{e.message}")
      false
    end

    def close
      close_database
    end

    private

    def ensure_directory
      return if @db_path.empty? || @db_path == ':memory:'

      dir = File.dirname(@db_path)
      FileUtils.mkdir_p(dir)
    end

    def open_database
      return if @db_path.empty?

      # :memory: is supported for tests; file paths for real use.
      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = false
      @db.busy_timeout = 5_000
      @db.execute('PRAGMA foreign_keys = ON')
      @db.execute('PRAGMA journal_mode = DELETE') # simple and safe default

      return if @db_path == ':memory:'
      return if File.file?(@db_path)

      raise Errno::ENOENT, "SQLite database file was not created at #{@db_path}"
    end

    def ensure_schema
      return unless @db

      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS price_history (
          scraped_at INTEGER NOT NULL,
          metric_name TEXT NOT NULL,
          value REAL NOT NULL,
          help_text TEXT,
          PRIMARY KEY (scraped_at, metric_name)
        )
      SQL

      @db.execute(<<~SQL)
        CREATE INDEX IF NOT EXISTS idx_price_history_scraped_at
        ON price_history (scraped_at)
      SQL
    end

    def close_database
      @db&.close
    rescue StandardError
      # ignore close errors
    ensure
      @db = nil
    end

    def accumulate_row!(points_by_time, help, row)
      ts = row[0].to_i
      metric = row[1]
      val = row[2].to_f
      h = row[3]

      points_by_time[ts] ||= {}
      points_by_time[ts][metric] = val
      help[metric] = h if h && !h.empty?
    end

    def log_error(message)
      if @log.respond_to?(:error)
        @log.error(message)
      else
        warn "[PriceHistoryStore] #{message}"
      end
    end

    def log_info(message)
      if @log.respond_to?(:info)
        @log.info(message)
      else
        warn "[PriceHistoryStore] #{message}"
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
