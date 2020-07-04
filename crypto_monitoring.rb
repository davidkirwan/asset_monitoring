# curl https://api.coinbase.com/v2/prices/BTC-EUR/spot
# {"data":{"base":"BTC","currency":"EUR","amount":"8882.40801808"}}
#
# curl https://api.coinbase.com/v2/prices/ETH-EUR/spot
# {"data":{"base":"ETH","currency":"EUR","amount":"193.34586846"}}
#
require 'sinatra/base'
require 'logger'
require 'json'
require 'puma'
require 'curb'


module Crypto
  class Monitoring < Sinatra::Base
    enable :static, :sessions, :logging

    set :environment, :production
    set :root, File.dirname(__FILE__)
    set :public_folder, File.join(root, '/public')
    set :views, File.join(root, '/views')
    set :server, :puma

    # Create the logger instance
    set :log, Logger.new(STDOUT)
    set :level, Logger::DEBUG
    #set :level, Logger::INFO
    #set :level, Logger::WARN


    not_found do
      [404, {"Content-Type" => "text/plain"},["404 not found"]]
    end

    get '/metrics' do
      begin
        btc_eur = Curl.get("https://api.coinbase.com/v2/prices/BTC-EUR/spot")
        btc_eur_json = JSON.parse(btc_eur.body_str)
        btc_spot = btc_eur_json["data"]["amount"]
        settings.log.debug(btc_spot)
        
        eth_eur = Curl.get("https://api.coinbase.com/v2/prices/ETH-EUR/spot")
        eth_eur_json = JSON.parse(eth_eur.body_str)
        eth_spot = eth_eur_json["data"]["amount"]
        settings.log.debug(eth_spot)

        res = <<-RESPONSE
# HELP crypto_btc_eur The spot price of Bitcoin in Euro
# TYPE crypto_btc_eur gauge
crypto_btc_eur{currency1="Bitcoin", ticker1="BTC", currency2="Euro", ticker2="€", exchange="Coinbase", result="succeeded"} #{btc_spot}
# HELP crypto_eth_eur The spot price of Ethereum in Euro
# TYPE crypto_eth_eur gauge
crypto_eth_eur{currency1="Ethereum", ticker1="ETH", currency2="Euro", ticker2="€", exchange="Coinbase", result="succeeded"} #{eth_spot}
        RESPONSE

        [200, {"Content-Type" => "text/plain"},[res]]
      rescue Exception => e
	settings.log.debug(e)
        [500, {"Content-Type" => "text/plain"},["500 internal server error"]]
      end
    end

  end
end
