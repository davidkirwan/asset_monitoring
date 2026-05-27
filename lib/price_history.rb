# frozen_string_literal: true

require_relative 'prometheus_gauge_parse'
require_relative 'price_history_store'

module Asset
  # In-memory (and optionally SQLite-backed) history of parsed gauge values.
  # Retention is configurable via PRICE_HISTORY_RETENTION_DAYS (default 7).
  # When PRICE_HISTORY_DB_PATH is set, data is also persisted to SQLite and
  # hydrated on startup so history survives process restarts.
  class PriceHistory
    DEFAULT_RETENTION_DAYS = 7
    MUTEX = Mutex.new
    @points = []
    @help = {}
    @store = nil
    @retention_days = DEFAULT_RETENTION_DAYS

    class << self
      def configure_from_env!
        @retention_days = resolve_retention_days
        db_path = ENV.fetch('PRICE_HISTORY_DB_PATH', '').to_s.strip

        if db_path.empty?
          @store = nil
          return
        end

        log = resolve_logger
        @store = PriceHistoryStore.new(db_path, retention_days: @retention_days, log: log)
        hydrate_from_store! if @store&.enabled?
      end

      private_class_method def resolve_retention_days
        val = ENV.fetch('PRICE_HISTORY_RETENTION_DAYS', DEFAULT_RETENTION_DAYS.to_s).to_i
        val.positive? ? val : DEFAULT_RETENTION_DAYS
      end

      private_class_method def resolve_logger
        return nil unless defined?(Asset::Monitoring)

        settings = Asset::Monitoring.settings
        return nil unless settings.respond_to?(:log)

        settings.log
      end

      attr_reader :retention_days

      def clear!
        MUTEX.synchronize do
          @points = []
          @help = {}
        end
        @store&.clear!
      end

      def record_scrape!(epoch, bullion_text, coin_text)
        v1, h1 = PrometheusGaugeParse.parse(bullion_text)
        v2, h2 = PrometheusGaugeParse.parse(coin_text)
        values = v1.merge(v2)
        help = h1.merge(h2)
        now = epoch.to_i

        MUTEX.synchronize do
          @help = help
          if (last = @points.last) && last[:t] == now
            @points[-1] = { t: now, v: values }
          else
            @points << { t: now, v: values }
          end
          trim_points!(Time.now.to_i)
        end

        @store&.append_scrape!(now, values, help)
      end

      def to_api_hash
        points, help = MUTEX.synchronize { [@points.dup, @help.dup] }
        all_keys = points.flat_map { |p| p[:v].keys }.uniq.sort
        series = all_keys.map do |key|
          {
            'id' => key,
            'label' => help[key] || key,
            'points' => points.filter_map { |p| p[:v][key] ? [p[:t], p[:v][key]] : nil }
          }
        end
        {
          'retention_days' => @retention_days,
          'scrape_count' => points.length,
          'updated_at' => Time.now.utc.iso8601(3),
          'series' => series
        }
      end

      private

      def retention_seconds
        @retention_days * 24 * 60 * 60
      end

      def trim_points!(now)
        min_t = now - retention_seconds
        @points.reject! { |p| p[:t] < min_t }
      end

      def hydrate_from_store!
        return unless @store&.enabled?

        points, help = @store.load_recent
        MUTEX.synchronize do
          @points = points
          @help = help
          trim_points!(Time.now.to_i)
        end
      end
    end
  end
end
