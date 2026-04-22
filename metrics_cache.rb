# frozen_string_literal: true

require_relative 'price_history'

module Asset
  # Thread-safe store for spot metrics fetched on a background schedule.
  class MetricsCache
    MUTEX = Mutex.new
    @bullionvault = nil
    @coinbase = nil
    @last_scrape_at = nil
    @last_error = nil

    class << self
      def last_error
        MUTEX.synchronize { @last_error }
      end

      def last_scrape_epoch
        MUTEX.synchronize { @last_scrape_at&.to_i } || 0
      end

      def snapshot
        MUTEX.synchronize { [@bullionvault, @coinbase] }
      end

      def reset!
        PriceHistory.clear!
        MUTEX.synchronize do
          @bullionvault = nil
          @coinbase = nil
          @last_scrape_at = nil
          @last_error = nil
        end
      end

      def refresh_silent!(settings)
        bullion = BullionVault.spot(settings)
        coin = Coinbase.spot(settings)
        t = Time.now
        MUTEX.synchronize do
          @bullionvault = bullion
          @coinbase = coin
          @last_scrape_at = t
          @last_error = nil
        end
        PriceHistory.record_scrape!(t.to_i, bullion, coin)
      rescue StandardError => e
        MUTEX.synchronize { @last_error = e.message }
        settings.log.error("Metrics background refresh failed: #{e.message}")
      end

      def start!(app_class, interval:)
        st = app_class.settings
        refresh_silent!(st)
        return if interval <= 0

        Thread.new do
          loop do
            sleep interval
            refresh_silent!(st)
          end
        end
      end
    end
  end
end
