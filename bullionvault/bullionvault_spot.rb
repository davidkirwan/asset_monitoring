require 'open-uri'
require 'nokogiri'

module BullionVault
  class << self

    def spot(settings)
      # Security ID     Metal   Location
      @exchanges = {
	"AUXZU"=>{ "gauge_name"=>"bullion_gold_zurich_", "security_id"=>"AUXZU", "comodity"=>"Gold", "exchange"=>"Zurich"},
	"AUXLN"=>{ "gauge_name"=>"bullion_gold_london_", "security_id"=>"AUXLN", "comodity"=>"Gold", "exchange"=>"London"},
	"AUXNY"=>{ "gauge_name"=>"bullion_gold_newyork_", "security_id"=>"AUXNY", "comodity"=>"Gold", "exchange"=>"New York"},
	"AUXTR"=>{ "gauge_name"=>"bullion_gold_toronto_", "security_id"=>"AUXTR", "comodity"=>"Gold", "exchange"=>"Toronto"},
	"AUXSG"=>{ "gauge_name"=>"bullion_gold_singapore_", "security_id"=>"AUXSG", "comodity"=>"Gold", "exchange"=>"Singapore"},
	"AGXZU"=>{ "gauge_name"=>"bullion_silver_zurich_", "security_id"=>"AGXZU", "comodity"=>"Silver", "exchange"=>"Zurich"},
	"AGXLN"=>{ "gauge_name"=>"bullion_silver_london_", "security_id"=>"AGXLN", "comodity"=>"Silver", "exchange"=>"London"},
	"AGXTR"=>{ "gauge_name"=>"bullion_silver_toronto_", "security_id"=>"AGXTR", "comodity"=>"Silver", "exchange"=>"Toronto"},
	"AGXSG"=>{ "gauge_name"=>"bullion_silver_singapore_", "security_id"=>"AGXSG", "comodity"=>"Silver", "exchange"=>"Singapore"},
	"PTXLN"=>{ "gauge_name"=>"bullion_platinum_london_", "security_id"=>"PTXLN", "comodity"=>"Platinum", "exchange"=>"London"}
      }
      response = ""
      doc = Nokogiri::XML(URI.open("https://www.bullionvault.com/view_market_xml.do"))
      pitch = doc.xpath("//pitch")
      
      pitch.each do |i|
	begin
	  ex = @exchanges[i.attributes["securityId"].value]
	  exchange = ex['exchange']
	  comodity = ex['comodity']
	  currency = i.attributes['considerationCurrency']
	  gauge_buy = ex['gauge_name'] + "buy_" + currency.to_s.downcase
	  gauge_sell = ex['gauge_name'] + "sell_" + currency.to_s.downcase
	  description_buy = "The buy spot price of #{comodity} in the #{exchange} exchange in currency #{currency}. Quantities are listed in kg."
	  description_sell = "The buy spot price of #{comodity} in the #{exchange} exchange in currency #{currency}. Quantities are listed in kg."
	  buy_price = i.at_xpath("buyPrices").at_xpath("price").attributes["limit"].value
	  buy_qty = i.at_xpath("buyPrices").at_xpath("price").attributes["quantity"].value
	  sell_price = i.at_xpath("sellPrices").at_xpath("price").attributes["limit"].value
	  sell_qty = i.at_xpath("sellPrices").at_xpath("price").attributes["quantity"].value

	  settings.log.debug "# HELP #{gauge_buy } #{description_buy}"
	  settings.log.debug "# TYPE #{gauge_buy} gauge"
	  settings.log.debug "#{gauge_buy}{security_id='#{ex["security_id"]}', comodity='#{comodity}', exchange='#{exchange}', currency='#{currency.to_s.downcase}', qty='#{buy_qty}'} #{buy_price}"
	  settings.log.debug "# HELP #{gauge_sell } #{description_sell}"
	  settings.log.debug "# TYPE #{gauge_sell} gauge"
	  settings.log.debug "#{gauge_sell}{security_id='#{ex["security_id"]}', comodity='#{comodity}', exchange='#{exchange}', currency='#{currency.to_s.downcase}', qty='#{sell_qty}'} #{sell_price}"

          response += <<-RESPONSE
# HELP #{gauge_buy } #{description_buy}
# TYPE #{gauge_buy} gauge
#{gauge_buy}{security_id="#{ex["security_id"]}", comodity="#{comodity}", exchange="#{exchange}", currency="#{currency.to_s.downcase}", qty="#{buy_qty}"} #{buy_price}
# HELP #{gauge_sell } #{description_sell}
# TYPE #{gauge_sell} gauge
#{gauge_sell}{security_id="#{ex["security_id"]}", comodity="#{comodity}", exchange="#{exchange}", currency="#{currency.to_s.downcase}", qty="#{sell_qty}"} #{sell_price}
RESPONSE
	rescue Exception => e
	  settings.log.debug(e)
	  raise e
	end
      end
      return response
    end
  end
end

