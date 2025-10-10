# frozen_string_literal: true

require 'faraday'
require 'nokogiri'

module BullionVault
  class << self
    API_URL = 'https://www.bullionvault.com/view_market_xml.do'.freeze

    # Security ID mapping to exchange information
    EXCHANGES = {
      'AUXZU' => { 'gauge_name' => 'bullion_gold_zurich_', 'security_id' => 'AUXZU', 'commodity' => 'Gold', 'exchange' => 'Zurich' },
      'AUXLN' => { 'gauge_name' => 'bullion_gold_london_', 'security_id' => 'AUXLN', 'commodity' => 'Gold', 'exchange' => 'London' },
      'AUXNY' => { 'gauge_name' => 'bullion_gold_newyork_', 'security_id' => 'AUXNY', 'commodity' => 'Gold', 'exchange' => 'New York' },
      'AUXTR' => { 'gauge_name' => 'bullion_gold_toronto_', 'security_id' => 'AUXTR', 'commodity' => 'Gold', 'exchange' => 'Toronto' },
      'AUXSG' => { 'gauge_name' => 'bullion_gold_singapore_', 'security_id' => 'AUXSG', 'commodity' => 'Gold', 'exchange' => 'Singapore' },
      'AGXZU' => { 'gauge_name' => 'bullion_silver_zurich_', 'security_id' => 'AGXZU', 'commodity' => 'Silver', 'exchange' => 'Zurich' },
      'AGXLN' => { 'gauge_name' => 'bullion_silver_london_', 'security_id' => 'AGXLN', 'commodity' => 'Silver', 'exchange' => 'London' },
      'AGXTR' => { 'gauge_name' => 'bullion_silver_toronto_', 'security_id' => 'AGXTR', 'commodity' => 'Silver', 'exchange' => 'Toronto' },
      'AGXSG' => { 'gauge_name' => 'bullion_silver_singapore_', 'security_id' => 'AGXSG', 'commodity' => 'Silver', 'exchange' => 'Singapore' },
      'PTXLN' => { 'gauge_name' => 'bullion_platinum_london_', 'security_id' => 'PTXLN', 'commodity' => 'Platinum', 'exchange' => 'London' }
    }.freeze

    def spot(settings)
      settings.log.debug('Fetching BullionVault data')
      
      response = fetch_market_data(settings)
      doc = parse_xml(response)
      generate_metrics(doc, settings)
    rescue StandardError => e
      settings.log.error("BullionVault error: #{e.message}")
      raise e
    end

    private

    def fetch_market_data(settings)
      connection = Faraday.new do |conn|
        conn.request :retry, max: 3, interval: 1
        conn.options.timeout = 30
      end

      response = connection.get(API_URL)
      
      unless response.success?
        raise "BullionVault API returned #{response.status}: #{response.body}"
      end

      response.body
    end

    def parse_xml(xml_content)
      Nokogiri::XML(xml_content)
    rescue Nokogiri::XML::SyntaxError => e
      raise "Invalid XML response from BullionVault: #{e.message}"
    end

    def generate_metrics(doc, settings)
      metrics = []
      pitches = doc.xpath('//pitch')

      pitches.each do |pitch|
        begin
          exchange_data = extract_exchange_data(pitch)
          next unless exchange_data

          metrics << generate_pitch_metrics(exchange_data)
        rescue StandardError => e
          settings.log.warn("Error processing pitch: #{e.message}")
          next
        end
      end

      metrics.join("\n")
    end

    def extract_exchange_data(pitch)
      security_id = pitch.attributes['securityId']&.value
      return nil unless security_id && EXCHANGES.key?(security_id)

      exchange_info = EXCHANGES[security_id]
      currency = pitch.attributes['considerationCurrency']&.value
      return nil unless currency

      {
        exchange_info: exchange_info,
        currency: currency.downcase,
        buy_price: extract_price(pitch, 'buyPrices'),
        buy_quantity: extract_quantity(pitch, 'buyPrices'),
        sell_price: extract_price(pitch, 'sellPrices'),
        sell_quantity: extract_quantity(pitch, 'sellPrices')
      }
    end

    def extract_price(pitch, price_type)
      pitch.at_xpath("#{price_type}/price")&.attributes&.dig('limit')&.value
    end

    def extract_quantity(pitch, price_type)
      pitch.at_xpath("#{price_type}/price")&.attributes&.dig('quantity')&.value
    end

    def generate_pitch_metrics(data)
      exchange_info = data[:exchange_info]
      currency = data[:currency]
      
      gauge_prefix = "#{exchange_info['gauge_name']}"
      commodity = exchange_info['commodity']
      exchange = exchange_info['exchange']
      security_id = exchange_info['security_id']

      labels = %(security_id="#{security_id}", commodity="#{commodity}", exchange="#{exchange}", currency="#{currency}")

      <<~METRICS
        # HELP #{gauge_prefix}buy_#{currency} The buy spot price of #{commodity} in the #{exchange} exchange in currency #{currency.upcase}
        # TYPE #{gauge_prefix}buy_#{currency} gauge
        #{gauge_prefix}buy_#{currency}{#{labels}} #{data[:buy_price]}
        
        # HELP #{gauge_prefix}buy_#{currency}_qty The quantity of #{commodity} bought in the #{exchange} exchange in currency #{currency.upcase}. Quantities are listed in kg
        # TYPE #{gauge_prefix}buy_#{currency}_qty gauge
        #{gauge_prefix}buy_#{currency}_qty{#{labels}} #{data[:buy_quantity]}
        
        # HELP #{gauge_prefix}sell_#{currency} The sell spot price of #{commodity} in the #{exchange} exchange in currency #{currency.upcase}
        # TYPE #{gauge_prefix}sell_#{currency} gauge
        #{gauge_prefix}sell_#{currency}{#{labels}} #{data[:sell_price]}
        
        # HELP #{gauge_prefix}sell_#{currency}_qty The quantity of #{commodity} sold in the #{exchange} exchange in currency #{currency.upcase}. Quantities are listed in kg
        # TYPE #{gauge_prefix}sell_#{currency}_qty gauge
        #{gauge_prefix}sell_#{currency}_qty{#{labels}} #{data[:sell_quantity]}
      METRICS
    end
  end
end

