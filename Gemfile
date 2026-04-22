# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.4.0'

# Application gems
gem 'faraday', '2.14.1'
gem 'faraday-retry', '~> 2.2'
gem 'json', '2.15.2.1'
gem 'nokogiri', '1.19.1'
gem 'puma', '~> 6.0'
gem 'rack', '3.2.6'
gem 'rackup', '~> 2.2'
gem 'sinatra', '~> 4.0'

# Development and test gems
group :development, :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'pry', '~> 0.14'
  gem 'rack-test', '~> 2.1'
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.81', '< 1.86'
  gem 'rubocop-rspec', '~> 3.2'
  gem 'simplecov', '~> 0.22'
  gem 'vcr', '~> 6.1'
  gem 'webmock', '~> 3.18'
end

group :development do
  # rubygems 0.14.0 still calls `Bundler.with_clean_env` (removed in Bundler 4). Git master has the fix; no new release.
  gem 'rerun', git: 'https://github.com/alexch/rerun.git', ref: '4fbf9b25df4d03a5c9d2b8376ef89897e4a11b2b'
end
