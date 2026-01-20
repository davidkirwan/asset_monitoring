# frozen_string_literal: true

require 'sinatra/base'
require 'logger'
require 'json'
require_relative 'config/application'
require_relative 'bullionvault/bullionvault_spot'
require_relative 'coinbase/coinbase_spot'

module Asset
  class Monitoring < Sinatra::Base
    configure do
      config = Asset::Config.load
      set :environment, config[:environment]
      set :port, config[:port]
      set :log, Logger.new($stdout)
      enable :logging
    end

    get '/health' do
      content_type :json
      { status: 'healthy', timestamp: Time.now.iso8601 }.to_json
    end

    get '/ready' do
      content_type :json
      { status: 'ready', timestamp: Time.now.iso8601 }.to_json
    end

    get '/metrics' do
      content_type 'text/plain'

      metrics = [
        BullionVault.spot(settings),
        Coinbase.spot(settings),
        app_metrics
      ].compact

      [200, metrics.join("\n")]
    rescue StandardError => e
      settings.log.error("Error fetching metrics: #{e.message}")
      [500, "# Error fetching metrics: #{e.message}\n"]
    end

    not_found do
      [404, 'text/plain', '404 not found']
    end

    private

    def app_metrics
      <<~METRICS
        # HELP asset_monitoring_app_info Application information
        # TYPE asset_monitoring_app_info gauge
        asset_monitoring_app_info{version="#{ENV.fetch('APP_VERSION', 'unknown')}", environment="#{settings.environment}"} 1
        # HELP asset_monitoring_last_successful_fetch_seconds Timestamp of last successful metrics fetch
        # TYPE asset_monitoring_last_successful_fetch_seconds gauge
        asset_monitoring_last_successful_fetch_seconds #{Time.now.to_i}
      METRICS
    end
  end
end
