# frozen_string_literal: true

require 'faraday'
require 'json'

module Coinbase
  class << self
    BASE_URL = 'https://api.coinbase.com/v2/prices'.freeze
    EXCHANGE = 'Coinbase'.freeze

    # Supported cryptocurrency pairs
    CRYPTO_PAIRS = [
      { symbol: 'BTC', name: 'Bitcoin', currencies: %w[USD EUR] },
      { symbol: 'ETH', name: 'Ethereum', currencies: %w[USD EUR] }
    ].freeze

    def spot(settings)
      settings.log.debug('Fetching Coinbase data')
      
      connection = create_connection
      metrics = []

      CRYPTO_PAIRS.each do |crypto|
        crypto[:currencies].each do |currency|
          begin
            price_data = fetch_price(connection, crypto[:symbol], currency)
            metrics << generate_crypto_metrics(crypto, currency, price_data)
          rescue StandardError => e
            settings.log.warn("Error fetching #{crypto[:symbol]}-#{currency}: #{e.message}")
            next
          end
        end
      end

      metrics.join("\n")
    rescue StandardError => e
      settings.log.error("Coinbase error: #{e.message}")
      raise e
    end

    private

    def create_connection
      Faraday.new do |conn|
        conn.request :retry, max: 3, interval: 1
        conn.options.timeout = 30
        conn.headers['User-Agent'] = 'Asset-Monitoring/1.0'
      end
    end

    def fetch_price(connection, symbol, currency)
      url = "#{BASE_URL}/#{symbol}-#{currency}/spot"
      response = connection.get(url)
      
      unless response.success?
        raise "Coinbase API returned #{response.status}: #{response.body}"
      end

      data = JSON.parse(response.body)
      
      unless data['data'] && data['data']['amount']
        raise "Invalid response format from Coinbase API"
      end

      data['data']['amount']
    rescue JSON::ParserError => e
      raise "Invalid JSON response from Coinbase API: #{e.message}"
    end

    def generate_crypto_metrics(crypto, currency, price)
      symbol = crypto[:symbol]
      name = crypto[:name]
      currency_name = currency == 'USD' ? 'US Dollar' : 'Euro'
      ticker = currency == 'USD' ? 'USD' : 'EUR'
      
      metric_name = "crypto_#{symbol.downcase}_#{currency.downcase}"
      labels = %(currency1="#{name}", ticker1="#{symbol}", currency2="#{currency_name}", ticker2="#{ticker}", exchange="#{EXCHANGE}")

      <<~METRICS
        # HELP #{metric_name} The spot price of #{name} in #{currency_name}
        # TYPE #{metric_name} gauge
        #{metric_name}{#{labels}} #{price}
      METRICS
    end
  end
end
