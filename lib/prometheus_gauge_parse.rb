# frozen_string_literal: true

module Asset
  # Extracts # HELP and gauge data lines from Prometheus exposition text. Skips *_qty metrics.
  module PrometheusGaugeParse
    DATA_LINE = /\A([a-zA-Z_][\w_]*)\{[^}]*\}\s+(\S+)\s*\z/

    module_function

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def parse(prometheus_text)
      help = {}
      values = {}
      prometheus_text.to_s.each_line do |line|
        line = line.rstrip
        if (m = line.match(/\A# HELP ([^\s]+) (.+)\z/))
          help[Regexp.last_match(1)] = Regexp.last_match(2)
        elsif (m = line.match(DATA_LINE))
          name = m[1]
          next if name.end_with?('_qty')

          val = m[2]
          next if val.nil? || val.empty? || val.casecmp?('nan')

          num = Float(val, exception: false)
          next if num.nil?

          values[name] = num
        end
      end
      [values, help]
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
