# Makefile for asset-monitoring
#
# Mirrors the Rakefile. Run `make` or `make help` to see available commands.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

APP_HOST ?= 0.0.0.0
APP_PORT ?= 8080
CONTAINERFILE ?= Containerfile
IMAGE ?= asset-monitoring:latest
BUNDLE ?= bundle
BUNDLE_EXEC ?= $(BUNDLE) exec
RACKUP := $(BUNDLE_EXEC) rackup config.ru --host $(APP_HOST) -p $(APP_PORT)

.PHONY: help install server dev console \
        spec test rubocop lint check coverage \
        security audit brakeman \
        podman-build podman-run podman_build podman_run

.DEFAULT_GOAL := help

help: ## Display available commands
	@cat tasks/help.txt

install: ## Install dependencies via Bundler
	$(BUNDLE) install

server: ## Start the application server
	$(RACKUP)

dev: ## Start the application server with auto-reload (development)
	$(BUNDLE_EXEC) rerun -- $(RACKUP)

console: ## Start an interactive Pry console with the app loaded
	METRICS_SCHEDULER_DISABLED=1 $(BUNDLE_EXEC) pry -Ilib -r asset_monitoring

spec: ## Run RSpec tests
	$(BUNDLE_EXEC) rspec

test: spec ## Alias for spec

rubocop: ## Run RuboCop linter
	$(BUNDLE_EXEC) rubocop

lint: rubocop ## Alias for rubocop

check: rubocop spec ## Run all checks (rubocop + specs)

coverage: ## Run tests with coverage report
	COVERAGE=true $(BUNDLE_EXEC) rspec

audit: ## Run Bundler audit
	$(BUNDLE_EXEC) bundle-audit check --update

brakeman: ## Run Brakeman
	$(BUNDLE_EXEC) brakeman --no-pager

security: audit brakeman ## Run security checks (bundle-audit + brakeman)

podman-build: ## Build the container image tagged asset-monitoring:latest
	podman build -t $(IMAGE) -f $(CONTAINERFILE) .

podman-run: ## Run the container (port $(APP_PORT))
	podman run -p $(APP_PORT):$(APP_PORT) $(IMAGE)

podman_build: podman-build ## Alias for podman-build

podman_run: podman-run ## Alias for podman-run
