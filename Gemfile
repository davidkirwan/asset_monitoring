source 'https://rubygems.org'

ruby '3.2.0'

# Application gems
gem 'sinatra', '~> 3.0'
gem 'puma', '~> 6.0'
gem 'nokogiri', '~> 1.15'
gem 'faraday', '~> 2.7'  # Modern HTTP client instead of curb
gem 'json', '~> 2.6'

# Development and test gems
group :development, :test do
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-rspec', '~> 2.20'
  gem 'simplecov', '~> 0.22'
  gem 'webmock', '~> 3.18'
  gem 'vcr', '~> 6.1'
  gem 'pry', '~> 0.14'
end

group :development do
  gem 'rerun', '~> 0.14'  # Auto-reload during development
end
