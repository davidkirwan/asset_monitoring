# frozen_string_literal: true

module Asset
  # Shared portfolio asset IDs, units, and labels (no store/valuation dependencies).
  module PortfolioConstants
    ASSET_IDS = %w[gold silver platinum bitcoin ethereum stocks cash property pension].freeze
    SUMMARY_CURRENCIES = %w[EUR USD GBP JPY].freeze
    FIATS = SUMMARY_CURRENCIES.map(&:downcase).freeze
    METALS = %w[gold silver platinum].freeze
    FIAT_HOLDINGS = %w[stocks cash property pension].freeze

    ASSET_LABELS = {
      'gold' => 'Gold',
      'silver' => 'Silver',
      'platinum' => 'Platinum',
      'bitcoin' => 'Bitcoin',
      'ethereum' => 'Ethereum',
      'stocks' => 'Stocks',
      'cash' => 'Cash',
      'property' => 'Property',
      'pension' => 'Pension',
      'total' => 'Total portfolio'
    }.freeze

    UNITS = {
      'gold' => %w[troy_oz grams],
      'silver' => %w[troy_oz grams],
      'platinum' => %w[troy_oz grams],
      'bitcoin' => %w[btc satoshis],
      'ethereum' => %w[eth],
      'stocks' => %w[eur usd gbp jpy],
      'cash' => %w[eur usd gbp jpy],
      'property' => %w[eur usd gbp jpy],
      'pension' => %w[eur usd gbp jpy]
    }.freeze

    module_function

    def default_holding(asset_id)
      units = UNITS[asset_id] || ['eur']
      { 'amount' => '', 'unit' => units.first }
    end
  end
end
