# frozen_string_literal: true

require_relative 'prometheus_gauge_parse'

module Asset
  # In-memory 7-day history of parsed gauge values from the last N scrapes.
  class PriceHistory
    MAX_RETENTION_SEC = 7 * 24 * 60 * 60
    MUTEX = Mutex.new
    @points = []
    @help = {}

    class << self
      def clear!
        MUTEX.synchronize do
          @points = []
          @help = {}
        end
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
          'retention_days' => 7,
          'scrape_count' => points.length,
          'updated_at' => Time.now.utc.iso8601(3),
          'series' => series
        }
      end

      private

      def trim_points!(now)
        min_t = now - MAX_RETENTION_SEC
        @points.reject! { |p| p[:t] < min_t }
      end
    end
  end
end
