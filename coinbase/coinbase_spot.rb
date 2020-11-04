module Coinbase
  class << self
    def spot(settings)
      begin
        # BTC
        btc_usd  = Curl.get("https://api.coinbase.com/v2/prices/BTC-USD/spot")
        btc_usd_json = JSON.parse(btc_usd.body_str)
        btc_usd_spot = btc_usd_json["data"]["amount"]
        settings.log.debug(btc_usd_spot)

        btc_eur = Curl.get("https://api.coinbase.com/v2/prices/BTC-EUR/spot")
        btc_eur_json = JSON.parse(btc_eur.body_str)
        btc_eur_spot = btc_eur_json["data"]["amount"]
        settings.log.debug(btc_eur_spot)

        # ETH
        eth_usd = Curl.get("https://api.coinbase.com/v2/prices/ETH-USD/spot")
        eth_usd_json = JSON.parse(eth_usd.body_str)
        eth_usd_spot = eth_usd_json["data"]["amount"]
        settings.log.debug(eth_usd_spot)

        eth_eur = Curl.get("https://api.coinbase.com/v2/prices/ETH-EUR/spot")
        eth_eur_json = JSON.parse(eth_eur.body_str)
        eth_eur_spot = eth_eur_json["data"]["amount"]
        settings.log.debug(eth_eur_spot)

        res = <<-RESPONSE
# HELP crypto_btc_usd The spot price of Bitcoin in US Dollars
# TYPE crypto_btc_usd gauge
crypto_btc_usd{currency1="Bitcoin", ticker1="BTC", currency2="US Dollar", ticker2="USD", exchange="Coinbase"} #{btc_usd_spot}
# HELP crypto_btc_eur The spot price of Bitcoin in Euro
# TYPE crypto_btc_eur gauge
crypto_btc_eur{currency1="Bitcoin", ticker1="BTC", currency2="Euro", ticker2="EURO", exchange="Coinbase"} #{btc_eur_spot}
# HELP crypto_eth_usd The spot price of Ethereum in US Dollars
# TYPE crypto_eth_usd gauge
crypto_eth_usd{currency1="Ethereum", ticker1="ETH", currency2="USD Dollar", ticker2="USD", exchange="Coinbase"} #{eth_usd_spot}
# HELP crypto_eth_eur The spot price of Ethereum in Euro
# TYPE crypto_eth_eur gauge
crypto_eth_eur{currency1="Ethereum", ticker1="ETH", currency2="Euro", ticker2="EURO", exchange="Coinbase"} #{eth_eur_spot}
        RESPONSE
      rescue Exception => e
        settings.log.debug(e)
        raise e
      end
    end
  end
end
