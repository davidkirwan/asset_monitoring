# frozen_string_literal: true

require_relative 'portfolio_constants'

module Asset
  # Derives fiat cross-rates from multi-currency commodity spot quotes.
  module FxRates
    REFERENCE_ASSETS = %w[gold silver].freeze

    module_function

    def from_prices(prices)
      REFERENCE_ASSETS.each do |asset|
        quotes = prices[asset]
        next unless quotes.is_a?(Hash)

        available = PortfolioConstants::FIATS.select do |fiat|
          quotes[fiat].to_f.positive?
        end
        next if available.length < 2

        return available.to_h { |fiat| [fiat, quotes[fiat].to_f] }
      end
      nil
    end

    def convert(amount, from, to, reference_quotes)
      from = from.to_s.downcase
      to = to.to_s.downcase
      return amount.to_f if from == to
      return nil unless reference_quotes

      base = reference_quotes[from]&.to_f
      target = reference_quotes[to]&.to_f
      return nil unless base&.positive? && target&.positive?

      amount.to_f * (target / base)
    end

    def fiat_values(amount, unit, reference_quotes)
      unit = unit.to_s.downcase
      return native_fiat_values(amount, unit) unless reference_quotes

      PortfolioConstants::FIATS.to_h do |fiat|
        converted = convert(amount, unit, fiat, reference_quotes)
        next [fiat, nil] if converted.nil?

        [fiat, { 'quantity' => converted, 'value' => converted }]
      end
    end

    def native_fiat_values(amount, unit)
      PortfolioConstants::FIATS.to_h do |fiat|
        if fiat == unit
          [fiat, { 'quantity' => amount.to_f, 'value' => amount.to_f }]
        else
          [fiat, nil]
        end
      end
    end
  end
end
