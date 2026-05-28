# Multi-stage build for smaller production image
FROM ruby:3.4.8-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    sqlite-dev \
    && gem install bundler:4.0.10

WORKDIR /app

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/usr/local/bundle \
    GEM_HOME=/usr/local/bundle

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Install gems (clean binstubs; no host vendor/bundle)
RUN bundle install --jobs=4 --retry=3

# Production stage
FROM ruby:3.4.8-alpine AS production

# Install runtime dependencies
RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    sqlite \
    wget \
    && addgroup -g 1001 -S appgroup \
    && adduser -u 1001 -S appuser -G appgroup

ENV TZ=UTC \
    RACK_ENV=production \
    PORT=8080 \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/usr/local/bundle \
    GEM_HOME=/usr/local/bundle

WORKDIR /app

# Copy gems from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code (vendor/bundle excluded via .containerignore)
COPY --chown=appuser:appgroup Gemfile Gemfile.lock config.ru ./
COPY --chown=appuser:appgroup lib/ lib/
COPY --chown=appuser:appgroup views/ views/
COPY --chown=appuser:appgroup public/ public/

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["bundle", "exec", "rackup", "config.ru", "--host", "0.0.0.0", "-p", "8080"]
