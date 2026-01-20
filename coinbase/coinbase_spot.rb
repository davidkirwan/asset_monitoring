# frozen_string_literal: true

require 'faraday'
require 'json'

module Coinbase
  BASE_URL = 'https://api.coinbase.com/v2/prices'
  PAIRS = [
    { symbol: 'BTC', name: 'Bitcoin', currencies: %w[USD EUR] },
    { symbol: 'ETH', name: 'Ethereum', currencies: %w[USD EUR] }
  ].freeze

  def self.spot(settings)
    settings.log.debug('Fetching Coinbase data')
    conn = Faraday.new { |c| c.request :retry, max: 3, interval: 1 }

    metrics = PAIRS.flat_map do |crypto|
      crypto[:currencies].map { |currency| fetch_metric(conn, crypto, currency) }
    end

    metrics.join("\n")
  end

  def self.fetch_metric(conn, crypto, currency)
    response = conn.get("#{BASE_URL}/#{crypto[:symbol]}-#{currency}/spot")
    raise "API returned #{response.status}" unless response.success?

    price = JSON.parse(response.body).dig('data', 'amount')
    raise 'Invalid response format' unless price

    metric_name = "crypto_#{crypto[:symbol].downcase}_#{currency.downcase}"
    currency_name = currency == 'USD' ? 'US Dollar' : 'Euro'
    labels = %W[
      currency1="#{crypto[:name]}"
      ticker1="#{crypto[:symbol]}"
      currency2="#{currency_name}"
      ticker2="#{currency}"
      exchange="Coinbase"
    ].join(', ')

    <<~METRIC
      # HELP #{metric_name} The spot price of #{crypto[:name]} in #{currency_name}
      # TYPE #{metric_name} gauge
      #{metric_name}{#{labels}} #{price}
    METRIC
  end
end
