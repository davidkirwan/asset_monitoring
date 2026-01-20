# frozen_string_literal: true

module Asset
  module Config
    def self.load
      {
        environment: ENV.fetch('RACK_ENV', 'production'),
        log_level: ENV.fetch('LOG_LEVEL', 'INFO').upcase,
        port: ENV.fetch('PORT', '8080').to_i
      }
    end
  end
end
