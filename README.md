# Asset Monitoring

A modern Ruby-based asset monitoring application that fetches real-time precious metals and cryptocurrency prices and exposes them as Prometheus metrics for monitoring and alerting.

## Features

- **Real-time Data**: Fetches live prices from BullionVault (precious metals) and Coinbase (cryptocurrencies)
- **Prometheus Integration**: Exposes metrics in Prometheus format for monitoring
- **Health Checks**: Built-in health and readiness endpoints for Kubernetes
- **Modern Ruby**: Built with Ruby 3.2 and modern best practices
- **Comprehensive Testing**: Full test suite with RSpec and VCR
- **Code Quality**: RuboCop linting and SimpleCov coverage
- **Container Ready**: Optimized Docker image with multi-stage build
- **Kubernetes Native**: Complete Kubernetes manifests with security best practices
- **CI/CD Ready**: GitHub Actions workflow for automated testing and deployment

## Supported Assets

### Precious Metals (BullionVault)
- **Gold**: Zurich, London, New York, Toronto, Singapore
- **Silver**: Zurich, London, Toronto, Singapore  
- **Platinum**: London

### Cryptocurrencies (Coinbase)
- **Bitcoin (BTC)**: USD, EUR
- **Ethereum (ETH)**: USD, EUR

## Quick Start

### Using Docker

```bash
# Build the image
docker build -t asset-monitoring .

# Run the container
docker run -p 8080:8080 asset-monitoring

# Access metrics
curl http://localhost:8080/metrics

# Health check
curl http://localhost:8080/health
```

### Using Kubernetes

```bash
# Apply Kubernetes manifests
kubectl apply -f kubernetes/

# Check deployment status
kubectl get pods -n monitoring-example

# Access metrics via port-forward
kubectl port-forward -n monitoring-example svc/asset-monitoring 8080:8080
```

## Development Setup

### Prerequisites

- Ruby 3.2.0+
- Bundler 2.4+
- Docker (optional)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd asset_monitoring

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linting
bundle exec rubocop

# Start development server
bundle exec rerun 'bundle exec rackup -p 8080'
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RACK_ENV` | `production` | Ruby environment |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARN, ERROR) |
| `APP_VERSION` | `unknown` | Application version |

## API Endpoints

### `/metrics`
Returns Prometheus-formatted metrics for all supported assets.

**Example Response:**
```
# HELP crypto_btc_usd The spot price of Bitcoin in US Dollars
# TYPE crypto_btc_usd gauge
crypto_btc_usd{currency1="Bitcoin", ticker1="BTC", currency2="US Dollar", ticker2="USD", exchange="Coinbase"} 45000.00

# HELP bullion_gold_london_buy_eur The buy spot price of Gold in the London exchange in currency EUR
# TYPE bullion_gold_london_buy_eur gauge
bullion_gold_london_buy_eur{security_id="AUXLN", commodity="Gold", exchange="London", currency="eur"} 52000.00
```

### `/health`
Returns application health status for Kubernetes liveness probes.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### `/ready`
Returns application readiness status for Kubernetes readiness probes.

**Response:**
```json
{
  "status": "ready", 
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Monitoring and Alerting

The application includes comprehensive Prometheus rules for monitoring:

### Application Health
- Service availability
- Error rates
- Data freshness

### Asset Price Alerts
- Bitcoin price thresholds (high/low)
- Ethereum price thresholds (high/low)
- Gold price alerts
- Silver price alerts

### Example Queries

```promql
# Current Bitcoin price in EUR
crypto_btc_eur

# Gold price across all exchanges
bullion_gold_*_buy_eur

# Application uptime
up{job="asset-monitoring"}

# Data freshness
time() - asset_monitoring_last_successful_fetch_seconds
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │  Asset Monitoring │    │   Data Sources  │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │ Prometheus  │◄┼────┼─┤ /metrics     │ │    │ │ BullionVault│ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
│                 │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ ┌─────────────┐ │    │ │ /health      │ │    │ │ Coinbase    │ │
│ │ Grafana     │◄┼────┼─┤ /ready       │ │    │ └─────────────┘ │
│ └─────────────┘ │    │ └──────────────┘ │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Testing

The application includes comprehensive tests:

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/asset_monitoring_spec.rb

# Run tests with VCR (records API interactions)
bundle exec rspec --tag vcr
```

### Test Structure

- `spec/asset_monitoring_spec.rb` - Main application tests
- `spec/bullionvault_spec.rb` - BullionVault module tests  
- `spec/coinbase_spec.rb` - Coinbase module tests
- `spec/fixtures/vcr_cassettes/` - Recorded API responses

## Code Quality

The project enforces code quality through:

- **RuboCop**: Ruby linting and style enforcement
- **SimpleCov**: Test coverage reporting
- **RSpec**: Comprehensive test suite
- **VCR**: API response recording for reliable tests

```bash
# Run linting
bundle exec rubocop

# Run linting with auto-fix
bundle exec rubocop -a

# Check test coverage
COVERAGE=true bundle exec rspec
open coverage/index.html
```

## Deployment

### Docker

```bash
# Build production image
docker build -t quay.io/dkirwan/asset_monitoring:latest .

# Push to registry
docker push quay.io/dkirwan/asset_monitoring:latest
```

### Kubernetes

```bash
# Create namespace
kubectl create namespace monitoring-example

# Apply all manifests
kubectl apply -f kubernetes/

# Check deployment
kubectl get all -n monitoring-example
```

### CI/CD

The project includes GitHub Actions workflows for:

- Automated testing on pull requests
- Security scanning
- Docker image building and pushing
- Kubernetes deployment

## Configuration

### Kubernetes Configuration

The Kubernetes manifests include:

- **Security**: Non-root user, read-only filesystem, dropped capabilities
- **Resources**: CPU and memory limits
- **Health Checks**: Liveness and readiness probes
- **Monitoring**: Prometheus ServiceMonitor and alerting rules

### Environment Configuration

All configuration is done through environment variables for 12-factor app compliance.

## Troubleshooting

### Common Issues

1. **API Timeouts**: Check network connectivity to BullionVault and Coinbase
2. **High Memory Usage**: Adjust resource limits in Kubernetes deployment
3. **Stale Data**: Check the `asset_monitoring_last_successful_fetch_seconds` metric

### Logs

```bash
# View application logs
kubectl logs -n monitoring-example deployment/asset-monitoring

# Follow logs
kubectl logs -f -n monitoring-example deployment/asset-monitoring
```

### Debugging

```bash
# Enable debug logging
kubectl set env -n monitoring-example deployment/asset-monitoring LOG_LEVEL=DEBUG

# Check health endpoint
kubectl exec -n monitoring-example deployment/asset-monitoring -- wget -qO- http://localhost:8080/health
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Run RuboCop and fix any issues
7. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review existing GitHub issues
3. Create a new issue with detailed information

## Changelog

### v1.0.0
- Complete rewrite with modern Ruby practices
- Added comprehensive testing and CI/CD
- Improved error handling and logging
- Enhanced security and monitoring
- Updated Kubernetes manifests
- Added health check endpoints