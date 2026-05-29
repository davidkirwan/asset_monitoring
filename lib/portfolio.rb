# frozen_string_literal: true

require_relative 'portfolio_store'
require_relative 'portfolio_valuation'
require_relative 'spot_prices'

module Asset
  # Portfolio holdings facade used by the web UI and API.
  class Portfolio
    @store = nil

    class << self
      def configure_from_env!(root: nil)
        db_path = resolve_db_path(root)
        if db_path.empty?
          @store = nil
          log_warn('Portfolio persistence disabled; set PORTFOLIO_DB_PATH or PRICE_HISTORY_DB_PATH')
          return
        end

        store = PortfolioStore.new(db_path, log: resolve_logger)
        unless store.enabled?
          @store = nil
          log_warn("Portfolio persistence disabled; could not open #{db_path}")
          return
        end

        @store = store
        log_info("Portfolio persistence enabled at #{db_path}")
      end

      def to_api_hash
        return PortfolioStore.default_payload.merge('persisted' => false) unless @store&.enabled?

        @store.load
      end

      def history_api_hash
        return default_empty_history unless @store&.enabled?

        @store.load_history
      end

      def save!(payload)
        return { 'ok' => false, 'error' => 'Portfolio persistence is not configured' } unless @store&.enabled?

        if @store.save!(payload)
          record_snapshot!
          { 'ok' => true, 'portfolio' => @store.load }
        else
          { 'ok' => false, 'error' => 'Failed to save portfolio' }
        end
      end

      def record_snapshot!(epoch = Time.now.to_i)
        return false unless @store&.enabled?

        holdings = @store.load['holdings']
        return false unless holdings_with_values?(holdings)

        prices = SpotPrices.current_prices
        return false if prices.empty?

        valuations = PortfolioValuation.compute(holdings, prices)
        totals = PortfolioValuation.totals(valuations)
        @store.record_snapshot!(epoch, valuations, totals: totals)
      end

      def enabled?
        @store&.enabled?
      end

      private

      def holdings_with_values?(holdings)
        holdings.any? do |_asset_id, holding|
          PortfolioValuation.parse_amount(holding['amount']).positive?
        end
      end

      def default_empty_history
        {
          'retention_days' => ENV.fetch('PRICE_HISTORY_RETENTION_DAYS', '365').to_i,
          'snapshot_count' => 0,
          'updated_at' => Time.now.utc.iso8601(3),
          'currencies' => PortfolioStore::SUMMARY_CURRENCIES.map(&:downcase),
          'assets' => PortfolioStore::ASSET_IDS.map do |asset_id|
            {
              'id' => asset_id,
              'label' => PortfolioValuation::ASSET_LABELS[asset_id],
              'values' => {}
            }
          end,
          'totals' => {},
          'persisted' => false
        }
      end

      def resolve_db_path(root)
        explicit = ENV.fetch('PORTFOLIO_DB_PATH', '').to_s.strip
        return explicit unless explicit.empty?

        shared = ENV.fetch('PRICE_HISTORY_DB_PATH', '').to_s.strip
        return shared unless shared.empty?

        return '' unless root && ENV.fetch('RACK_ENV', 'development') == 'development'

        File.expand_path(File.join('data', 'portfolio.db'), root)
      end

      def resolve_logger
        return nil unless defined?(Asset::Monitoring)

        settings = Asset::Monitoring.settings
        return nil unless settings.respond_to?(:log)

        settings.log
      end

      def log_info(message)
        log(:info, message)
      end

      def log_warn(message)
        log(:warn, message)
      end

      def log(level, message)
        logger = resolve_logger
        if logger.respond_to?(level)
          logger.public_send(level, message)
        else
          warn "[Portfolio] #{message}"
        end
      end
    end
  end
end
