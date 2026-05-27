# Makefile for asset-monitoring
#
# This provides the same functionality as the Rakefile.
# Run `make` or `make help` to see available commands.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: help spec rubocop check coverage install server dev console \
        docker_build docker_run docker-build docker-run test lint

.DEFAULT_GOAL := help

##@ General

help: ## Display available commands
	@echo 'Asset Monitoring - Available Commands'
	@echo '======================================'
	@echo ''
	@echo 'Setup:'
	@echo '  make install       - Install dependencies via Bundler'
	@echo ''
	@echo 'Development:'
	@echo '  make server        - Start the application server on 0.0.0.0:8080'
	@echo '  make dev           - Start with auto-reload (requires rerun gem)'
	@echo '  make console       - Start an interactive console'
	@echo ''
	@echo 'Testing:'
	@echo '  make spec          - Run RSpec tests'
	@echo '  make rubocop       - Run RuboCop linter'
	@echo '  make check         - Run all checks (rubocop + specs)'
	@echo '  make coverage      - Run tests with coverage report'
	@echo '  make test          - Alias for spec'
	@echo '  make lint          - Alias for rubocop'
	@echo ''
	@echo 'Docker:'
	@echo '  make docker_build  - Build the Docker image'
	@echo '  make docker_run    - Run the Docker container'
	@echo '  make docker-build  - Alias for docker_build'
	@echo '  make docker-run    - Alias for docker_run'
	@echo ''
	@echo 'Web UI (open in a browser, server on 0.0.0.0:8080):'
	@echo '  /                  - Redirects to /dashboard'
	@echo '  /dashboard         - Price charts (BullionVault + Coinbase; one point per background scrape). Retention configurable via PRICE_HISTORY_RETENTION_DAYS.'
	@echo ''
	@echo 'API / metrics (curl or similar):'
	@echo '  /api/price_history.json - JSON time series for the dashboard (same underlying data as /metrics, parsed). Includes retention_days.'
	@echo '  /metrics                - Prometheus text exposition (cached from last successful scrape)'
	@echo '  /health                 - Liveness JSON probe'
	@echo '  /ready                  - Readiness JSON probe'
	@echo ''
	@echo 'Optional SQLite persistence (survives restarts):'
	@echo '  Set PRICE_HISTORY_DB_PATH and (optionally) PRICE_HISTORY_RETENTION_DAYS.'
	@echo '  See README.asciidoc for Kubernetes PVC + replica considerations.'
	@echo ''

##@ Setup

install: ## Install dependencies via Bundler
	bundle install

##@ Development

server: ## Start the application server on 0.0.0.0:8080
	bundle exec rackup --host 0.0.0.0 -p 8080

dev: ## Start the application server with auto-reload (development)
	bundle exec rerun -- rackup --host 0.0.0.0 -p 8080

console: ## Start an interactive Pry console with the app loaded
	bundle exec ruby -Ilib -r asset_monitoring -r pry -e 'Pry.start'

##@ Testing

spec: ## Run RSpec tests
	bundle exec rspec

rubocop: ## Run RuboCop linter
	bundle exec rubocop

check: rubocop spec ## Run all checks (rubocop + specs)

coverage: ## Run tests with coverage (SimpleCov)
	COVERAGE=true bundle exec rspec

test: spec ## Alias for spec

lint: rubocop ## Alias for rubocop

##@ Docker

docker_build: ## Build the Docker image tagged asset-monitoring:latest
	docker build -t asset-monitoring:latest .

docker_run: ## Run the Docker container (port 8080)
	docker run -p 8080:8080 asset-monitoring:latest

docker-build: docker_build ## Alias for docker_build

docker-run: docker_run ## Alias for docker_run
