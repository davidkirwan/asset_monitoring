# frozen_string_literal: true

require 'sinatra/base'
require 'logger'
require 'json'
require 'puma'
require 'faraday'
require_relative 'config/application'
require_relative 'bullionvault/bullionvault_spot'
require_relative 'coinbase/coinbase_spot'

module Asset
  class Monitoring < Sinatra::Base
    enable :static, :sessions, :logging

    # Load configuration
    config = Asset::Config.load

    set :environment, config[:environment]
    set :root, File.dirname(__FILE__)
    set :public_folder, File.join(root, '/public')
    set :views, File.join(root, '/views')
    set :server, :puma
    set :port, config[:port]

    # Configure logging
    configure do
      set :log, Logger.new($stdout)
      set :level, Logger.const_get(config[:log_level])
    end

    # Health check endpoint for Kubernetes liveness probe
    get '/health' do
      content_type :json
      { status: 'healthy', timestamp: Time.now.iso8601 }.to_json
    end

    # Readiness check endpoint for Kubernetes readiness probe
    get '/ready' do
      content_type :json
      { status: 'ready', timestamp: Time.now.iso8601 }.to_json
    end

    # Main metrics endpoint
    get '/metrics' do
      content_type :text/plain
      
      begin
        metrics = []
        
        # Fetch BullionVault metrics
        bullionvault_metrics = fetch_bullionvault_metrics
        metrics << bullionvault_metrics if bullionvault_metrics
        
        # Fetch Coinbase metrics
        coinbase_metrics = fetch_coinbase_metrics
        metrics << coinbase_metrics if coinbase_metrics
        
        # Add application metrics
        metrics << generate_app_metrics
        
        [200, metrics.join("\n")]
      rescue StandardError => e
        settings.log.error("Error fetching metrics: #{e.message}")
        settings.log.debug(e.backtrace.join("\n"))
        [500, "# Error fetching metrics: #{e.message}\n"]
      end
    end

    not_found do
      content_type :text/plain
      [404, '404 not found']
    end

    error do
      content_type :text/plain
      settings.log.error("Application error: #{env['sinatra.error'].message}")
      [500, '500 internal server error']
    end

    private

    def fetch_bullionvault_metrics
      settings.log.debug('Fetching BullionVault metrics')
      BullionVault.spot(settings)
    rescue StandardError => e
      settings.log.error("BullionVault API error: #{e.message}")
      nil
    end

    def fetch_coinbase_metrics
      settings.log.debug('Fetching Coinbase metrics')
      Coinbase.spot(settings)
    rescue StandardError => e
      settings.log.error("Coinbase API error: #{e.message}")
      nil
    end

    def generate_app_metrics
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
