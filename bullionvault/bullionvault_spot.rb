# frozen_string_literal: true

require 'faraday'
require 'nokogiri'

module BullionVault
  API_URL = 'https://www.bullionvault.com/view_market_xml.do'

  EXCHANGES = {
    'AUXZU' => %w[Gold Zurich], 'AUXLN' => %w[Gold London], 'AUXNY' => ['Gold', 'New York'],
    'AUXTR' => %w[Gold Toronto], 'AUXSG' => %w[Gold Singapore],
    'AGXZU' => %w[Silver Zurich], 'AGXLN' => %w[Silver London],
    'AGXTR' => %w[Silver Toronto], 'AGXSG' => %w[Silver Singapore],
    'PTXLN' => %w[Platinum London]
  }.freeze

  def self.spot(settings)
    settings.log.debug('Fetching BullionVault data')

    conn = Faraday.new { |c| c.request :retry, max: 3, interval: 1 }
    response = conn.get(API_URL)
    raise "API returned #{response.status}" unless response.success?

    doc = Nokogiri::XML(response.body)
    pitches = doc.xpath('//pitch')
    raise 'Invalid XML: no pitch data found' if pitches.empty?

    pitches.filter_map { |pitch| parse_pitch(pitch, settings) }.join("\n")
  end

  def self.parse_pitch(pitch, settings)
    security_id = pitch['securityId']
    return unless EXCHANGES.key?(security_id)

    currency = pitch['considerationCurrency']&.downcase
    return unless currency

    commodity, exchange = EXCHANGES[security_id]
    gauge = "bullion_#{commodity.downcase}_#{exchange.downcase.gsub(' ', '')}_"
    labels = %(security_id="#{security_id}", commodity="#{commodity}", exchange="#{exchange}", currency="#{currency}")

    buy = pitch.at_xpath('buyPrices/price')
    sell = pitch.at_xpath('sellPrices/price')

    <<~METRICS
      # HELP #{gauge}buy_#{currency} The buy spot price of #{commodity} in #{exchange} in #{currency.upcase}
      # TYPE #{gauge}buy_#{currency} gauge
      #{gauge}buy_#{currency}{#{labels}} #{buy&.[]('limit')}
      # HELP #{gauge}buy_#{currency}_qty Quantity of #{commodity} bought in #{exchange} in #{currency.upcase} (kg)
      # TYPE #{gauge}buy_#{currency}_qty gauge
      #{gauge}buy_#{currency}_qty{#{labels}} #{buy&.[]('quantity')}
      # HELP #{gauge}sell_#{currency} The sell spot price of #{commodity} in #{exchange} in #{currency.upcase}
      # TYPE #{gauge}sell_#{currency} gauge
      #{gauge}sell_#{currency}{#{labels}} #{sell&.[]('limit')}
      # HELP #{gauge}sell_#{currency}_qty Quantity of #{commodity} sold in #{exchange} in #{currency.upcase} (kg)
      # TYPE #{gauge}sell_#{currency}_qty gauge
      #{gauge}sell_#{currency}_qty{#{labels}} #{sell&.[]('quantity')}
    METRICS
  rescue StandardError => e
    settings.log.warn("Error processing pitch: #{e.message}")
    nil
  end
end
