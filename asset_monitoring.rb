require 'sinatra/base'
require 'logger'
require 'json'
require 'puma'
require 'curb'
require_relative 'bullionvault/bullionvault_spot'
require_relative 'coinbase/coinbase_spot'


module Asset
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
        # Call the bullionvalt api
        res = BullionVault.spot(settings)
        # Call the coinbase api
        res += Coinbase.spot(settings)

        [200, {"Content-Type" => "text/plain"},[res]]
      rescue Exception => e
        settings.log.debug(e)
        [500, {"Content-Type" => "text/plain"},["500 internal server error"]]
      end
    end

  end
end
