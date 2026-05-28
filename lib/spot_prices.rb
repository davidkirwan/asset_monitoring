# frozen_string_literal: true

require_relative 'prometheus_gauge_parse'
require_relative 'metrics_cache'
require_relative 'portfolio_constants'
require_relative 'fx_rates'

module Asset
  # Latest spot prices from the metrics cache, structured for the portfolio UI.
  module SpotPrices
    METALS = {
      'gold' => 'bullion_gold_london_buy',
      'silver' => 'bullion_silver_london_buy'
    }.freeze
    CRYPTOS = {
      'bitcoin' => 'crypto_btc',
      'ethereum' => 'crypto_eth'
    }.freeze
    FIATS = %w[usd eur gbp jpy].freeze
    METAL_PRICE_UNIT = 'per_kg'
    CRYPTO_PRICE_UNIT = 'per_coin'

    module_function

    def to_api_hash
      prices = current_prices
      return empty_response if prices.empty?

      {
        'updated_at' => Time.now.utc.iso8601(3),
        'last_scrape_epoch' => MetricsCache.last_scrape_epoch,
        'units' => {
          'gold' => METAL_PRICE_UNIT,
          'silver' => METAL_PRICE_UNIT,
          'bitcoin' => CRYPTO_PRICE_UNIT,
          'ethereum' => CRYPTO_PRICE_UNIT
        },
        'prices' => prices,
        'fx_reference' => fx_reference_label(prices),
        'fx_quotes' => FxRates.from_prices(prices)
      }
    end

    def current_prices
      bv, cb = MetricsCache.snapshot
      text = [bv, cb].compact.join("\n")
      return {} if text.empty?

      values, = PrometheusGaugeParse.parse(text)
      build_prices(values)
    end

    def build_prices(values)
      prices = {}
      METALS.each do |asset, prefix|
        prices[asset] = FIATS.filter_map do |fiat|
          key = "#{prefix}_#{fiat}"
          next unless values[key]

          [fiat, values[key]]
        end.to_h
      end
      CRYPTOS.each do |asset, prefix|
        prices[asset] = FIATS.filter_map do |fiat|
          key = "#{prefix}_#{fiat}"
          next unless values[key]

          [fiat, values[key]]
        end.to_h
      end
      prices
    end

    def empty_response
      {
        'updated_at' => Time.now.utc.iso8601(3),
        'last_scrape_epoch' => 0,
        'units' => {},
        'prices' => {},
        'fx_reference' => nil,
        'fx_quotes' => nil
      }
    end

    def fx_reference_label(prices)
      FxRates::REFERENCE_ASSETS.find do |asset|
        quotes = prices[asset]
        next unless quotes.is_a?(Hash)

        PortfolioConstants::FIATS.count { |fiat| quotes[fiat].to_f.positive? } >= 2
      end
    end
  end
end
