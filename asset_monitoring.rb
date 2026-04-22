# frozen_string_literal: true

require 'sinatra/base'
require 'logger'
require 'json'
require_relative 'config/application'
require_relative 'bullionvault/bullionvault_spot'
require_relative 'coinbase/coinbase_spot'
require_relative 'metrics_cache'

module Asset
  class Monitoring < Sinatra::Base
    configure do
      config = Asset::Config.load
      set :environment, config[:environment]
      set :port, config[:port]
      set :log, Logger.new($stdout)
      enable :logging

      unless ENV['RACK_ENV'] == 'test' || ENV['METRICS_SCHEDULER_DISABLED'] == '1'
        interval = ENV.fetch('METRICS_SCRAPE_INTERVAL_SECONDS', '3600').to_i
        Asset::MetricsCache.start!(self, interval: interval)
      end
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

      bv, cb = Asset::MetricsCache.snapshot
      if bv.nil? && cb.nil?
        err = Asset::MetricsCache.last_error || 'Metrics not yet available'
        settings.log.error("Error fetching metrics: #{err}")
        return [500, "# Error fetching metrics: #{err}\n"]
      end

      metrics = [bv, cb, app_metrics].compact
      [200, metrics.join("\n")]
    rescue StandardError => e
      settings.log.error("Error fetching metrics: #{e.message}")
      [500, "# Error fetching metrics: #{e.message}\n"]
    end

    not_found do
      content_type 'text/plain'
      '404 not found'
    end

    private

    def app_metrics
      t = Asset::MetricsCache.last_scrape_epoch
      <<~METRICS
        # HELP asset_monitoring_app_info Application information
        # TYPE asset_monitoring_app_info gauge
        asset_monitoring_app_info{version="#{ENV.fetch('APP_VERSION', 'unknown')}", environment="#{settings.environment}"} 1
        # HELP asset_monitoring_last_successful_fetch_seconds Timestamp of last successful background scrape
        # TYPE asset_monitoring_last_successful_fetch_seconds gauge
        asset_monitoring_last_successful_fetch_seconds #{t}
      METRICS
    end
  end
end
