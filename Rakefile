# frozen_string_literal: true

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

desc 'Start the application server'
task :server do
  sh 'bundle exec rackup -p 8080'
end

desc 'Start the application server with auto-reload (development)'
task :dev do
  sh 'bundle exec rerun -- rackup -p 8080'
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

    Development:
      rake server        - Start the application server on port 8080
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

    Endpoints (when server is running):
      curl http://localhost:8080/metrics  - Prometheus metrics
      curl http://localhost:8080/health   - Health check
      curl http://localhost:8080/ready    - Readiness check

  HELP
end

desc 'Start an interactive console'
task :console do
  require_relative 'asset_monitoring'
  require 'pry'
  Pry.start
end
