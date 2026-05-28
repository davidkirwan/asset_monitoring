# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# RVM (and similar) gem binstubs use `ruby_executable_hooks`; ensure it is on PATH
# when Rake spawns subshells via `sh`.
def ensure_gem_exec_path!
  paths = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
  [ENV['GEM_HOME'], Gem.dir].compact.filter_map do |base|
    File.join(base, 'bin') if base && !base.empty?
  end.each do |bin|
    paths.unshift(bin) unless paths.include?(bin)
  end
  ENV['PATH'] = paths.join(File::PATH_SEPARATOR)
end

ensure_gem_exec_path!

APP_HOST = ENV.fetch('HOST', '0.0.0.0')
APP_PORT = ENV.fetch('PORT', '8080')
CONTAINERFILE = 'Containerfile'
IMAGE = 'asset-monitoring:latest'
DATA_DIR = File.expand_path(ENV.fetch('DATA_DIR', 'data'), __dir__)
CONTAINER_DATA_DIR = '/data'
PRICE_HISTORY_DB_PATH = File.join(CONTAINER_DATA_DIR, 'asset_history.db')
RACKUP_CMD = ['bundle', 'exec', 'rackup', 'config.ru', '--host', APP_HOST, '-p', APP_PORT]

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

desc 'Run RSpec tests'
task test: :spec

desc 'Run RuboCop linter'
task lint: :rubocop

desc 'Run all checks (rubocop + specs)'
task check: %i[rubocop spec]

desc 'Run tests with coverage report'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].reenable
  Rake::Task['spec'].invoke
end

namespace :security do
  desc 'Run Bundler audit'
  task :audit do
    sh 'bundle', 'exec', 'bundle-audit', 'check', '--update'
  end

  desc 'Run Brakeman'
  task :brakeman do
    sh 'bundle', 'exec', 'brakeman', '--no-pager'
  end
end

desc 'Run security checks (bundle-audit + brakeman)'
task security: %w[security:audit security:brakeman]

desc 'Run Bundler audit'
task audit: 'security:audit'

desc 'Run Brakeman'
task brakeman: 'security:brakeman'

desc 'Install dependencies'
task :install do
  sh 'bundle', 'install'
end

desc 'Start the application server'
task :server do
  sh(*RACKUP_CMD)
end

desc 'Start the application server with auto-reload (development)'
task :dev do
  sh 'bundle', 'exec', 'rerun', '--', *RACKUP_CMD
end

desc 'Start an interactive console'
task :console do
  ENV['METRICS_SCHEDULER_DISABLED'] = '1'
  sh 'bundle', 'exec', 'pry', '-Ilib', '-r', 'asset_monitoring'
end

namespace :podman do
  desc 'Build the container image'
  task :build do
    sh 'podman', 'build', '-t', IMAGE, '-f', CONTAINERFILE, '.'
  end

  desc 'Run the container (1-year price history, SQLite in ./data bind-mounted to /data)'
  task :run do
    retention_days = ENV.fetch('PRICE_HISTORY_RETENTION_DAYS', '365')
    db_path = ENV.fetch('PRICE_HISTORY_DB_PATH', PRICE_HISTORY_DB_PATH)
    portfolio_db_path = ENV.fetch('PORTFOLIO_DB_PATH', File.join(File.dirname(db_path), 'portfolio.db'))
    container_data_dir = File.dirname(db_path)

    FileUtils.mkdir_p(DATA_DIR)

    sh 'podman', 'run', '--rm',
       '-p', "#{APP_PORT}:#{APP_PORT}",
       '-e', "PRICE_HISTORY_RETENTION_DAYS=#{retention_days}",
       '-e', "PRICE_HISTORY_DB_PATH=#{db_path}",
       '-e', "PORTFOLIO_DB_PATH=#{portfolio_db_path}",
       '-v', "#{DATA_DIR}:#{container_data_dir}:Z,U",
       IMAGE
  end
end

desc 'Build the container image (alias for podman:build)'
task podman_build: 'podman:build'

desc 'Run the container (alias for podman:run)'
task podman_run: 'podman:run'

desc 'Display available commands'
task :help do
  puts File.read(File.expand_path('tasks/help.txt', __dir__))
end

task default: :help
