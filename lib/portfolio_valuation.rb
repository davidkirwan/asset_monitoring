# frozen_string_literal: true

require_relative 'portfolio_constants'
require_relative 'fx_rates'

module Asset
  # Computes portfolio asset values in EUR, USD, GBP, and JPY from holdings and spot prices.
  module PortfolioValuation
    TROY_OZ_TO_KG = 0.0311034768
    SATOSHIS_PER_BTC = 100_000_000

    ASSET_LABELS = PortfolioConstants::ASSET_LABELS
    FIATS = PortfolioConstants::FIATS

    module_function

    def compute(holdings, prices)
      PortfolioConstants::ASSET_IDS.to_h do |asset_id|
        holding = holdings[asset_id] || PortfolioConstants.default_holding(asset_id)
        [asset_id, compute_asset(asset_id, holding, prices)]
      end
    end

    def totals(valuations)
      sums = FIATS.to_h { |fiat| [fiat, 0.0] }
      valuations.each_value do |currencies|
        currencies.each do |fiat, data|
          next unless data

          sums[fiat] += data['value'].to_f
        end
      end
      sums.transform_values { |v| v.positive? ? v : nil }
    end

    def compute_asset(asset_id, holding, prices)
      amount = parse_amount(holding['amount'])
      return empty_currencies if amount <= 0

      unit = holding['unit'].to_s.downcase
      asset_prices = prices[asset_id] || {}

      case asset_id
      when 'gold', 'silver', 'platinum'
        kg = metal_to_kg(amount, unit)
        price_values(asset_prices) { |price| { 'quantity' => kg, 'value' => kg * price } }
      when 'bitcoin'
        coins = bitcoin_amount(amount, unit)
        price_values(asset_prices) { |price| { 'quantity' => coins, 'value' => coins * price } }
      when 'ethereum'
        return empty_currencies unless unit == 'eth'

        price_values(asset_prices) { |price| { 'quantity' => amount, 'value' => amount * price } }
      when 'stocks', 'cash', 'property', 'pension'
        FxRates.fiat_values(amount, unit, FxRates.from_prices(prices))
      else
        empty_currencies
      end
    end

    def parse_amount(value)
      Float(value.to_s.delete(',').strip)
    rescue ArgumentError, TypeError
      0.0
    end

    def metal_to_kg(amount, unit)
      case unit
      when 'troy_oz' then amount * TROY_OZ_TO_KG
      when 'grams' then amount / 1000.0
      else 0.0
      end
    end

    def bitcoin_amount(amount, unit)
      case unit
      when 'btc' then amount
      when 'satoshis' then amount / SATOSHIS_PER_BTC
      else 0.0
      end
    end

    def price_values(asset_prices)
      FIATS.to_h do |fiat|
        price = asset_prices[fiat]
        next [fiat, nil] if price.nil?

        [fiat, yield(price.to_f)]
      end
    end

    def empty_currencies
      FIATS.to_h { |fiat| [fiat, nil] }
    end
  end
end
