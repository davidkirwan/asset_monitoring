# frozen_string_literal: true

module Asset
  module Config
    class << self
      def load
        {
          environment: ENV.fetch('RACK_ENV', 'production'),
          log_level: ENV.fetch('LOG_LEVEL', 'INFO').upcase,
          app_version: ENV.fetch('APP_VERSION', 'unknown'),
          port: ENV.fetch('PORT', '8080').to_i,
          
          # API Configuration
          bullionvault: {
            url: ENV.fetch('BULLIONVAULT_URL', 'https://www.bullionvault.com/view_market_xml.do'),
            timeout: ENV.fetch('BULLIONVAULT_TIMEOUT', '30').to_i,
            retries: ENV.fetch('BULLIONVAULT_RETRIES', '3').to_i
          },
          
          coinbase: {
            url: ENV.fetch('COINBASE_URL', 'https://api.coinbase.com/v2/prices'),
            timeout: ENV.fetch('COINBASE_TIMEOUT', '30').to_i,
            retries: ENV.fetch('COINBASE_RETRIES', '3').to_i
          },
          
          # Monitoring Configuration
          monitoring: {
            metrics_path: ENV.fetch('METRICS_PATH', '/metrics'),
            health_path: ENV.fetch('HEALTH_PATH', '/health'),
            ready_path: ENV.fetch('READY_PATH', '/ready')
          }
        }
      end
    end
  end
end