# frozen_string_literal: true

require 'bundler/setup'

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

desc 'Run all checks (rubocop + specs)'
task check: %i[rubocop spec]

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].invoke
end

desc 'Install dependencies'
task :install do
  sh 'bundle install'
end

desc 'Start the application server'
task :server do
  sh 'bundle exec rackup --host 0.0.0.0 -p 8080'
end

desc 'Start the application server with auto-reload (development)'
task :dev do
  sh 'bundle exec rerun -- rackup --host 0.0.0.0 -p 8080'
end

desc 'Build the Docker image'
task :docker_build do
  sh 'docker build -t asset-monitoring:latest .'
end

desc 'Run the Docker container'
task :docker_run do
  sh 'docker run -p 8080:8080 asset-monitoring:latest'
end

desc 'Display available commands'
task :default do
  puts <<~HELP
    Asset Monitoring - Available Commands
    ======================================

    Setup:
      rake install       - Install dependencies via Bundler

    Development:
      rake server        - Start the application server on 0.0.0.0:8080
      rake dev           - Start with auto-reload (requires rerun gem)
      rake console       - Start an interactive console

    Testing:
      rake spec          - Run RSpec tests
      rake rubocop       - Run RuboCop linter
      rake check         - Run all checks (rubocop + specs)
      rake coverage      - Run tests with coverage report

    Docker:
      rake docker_build  - Build the Docker image
      rake docker_run    - Run the Docker container

    Web UI (open in a browser, server on 0.0.0.0:8080):
      /                  - Redirects to /dashboard
      /dashboard         - 7-day price charts (BullionVault + Coinbase; one point per background scrape)

    API / metrics (curl or similar):
      /api/price_history.json - JSON time series for the dashboard (same underlying data as /metrics, parsed)
      /metrics                - Prometheus text exposition (cached from last successful scrape)
      /health                 - Liveness JSON probe
      /ready                  - Readiness JSON probe

  HELP
end

desc 'Start an interactive console'
task :console do
  $LOAD_PATH.unshift File.expand_path('lib', __dir__)
  require 'asset_monitoring'
  require 'pry'
  Pry.start
end
