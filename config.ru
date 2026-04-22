# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'asset_monitoring'

run Asset::Monitoring
