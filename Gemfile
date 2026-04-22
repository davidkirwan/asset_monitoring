# frozen_string_literal: true

source 'https://rubygems.org'

ruby '~> 3.4.0'

# Application gems
gem 'faraday', '~> 2.7'
gem 'faraday-retry', '~> 2.2'
gem 'json', '~> 2.6'
gem 'nokogiri', '~> 1.15'
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
  gem 'rerun', '~> 0.14'
end
