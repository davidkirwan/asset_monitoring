# Multi-stage build for smaller production image
FROM ruby:3.2.0-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    && gem install bundler:2.4.22

WORKDIR /app

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle install --jobs=4 --retry=3

# Production stage
FROM ruby:3.2.0-alpine AS production

# Install runtime dependencies
RUN apk add --no-cache \
    tzdata \
    ca-certificates \
    && addgroup -g 1001 -S appgroup \
    && adduser -u 1001 -S appuser -G appgroup

# Set timezone
ENV TZ=UTC

# Create app directory
WORKDIR /app

# Copy gems from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code
COPY --chown=appuser:appgroup . .

# Create non-root user and set permissions
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Set environment variables
ENV RACK_ENV=production
ENV PORT=8080

# Start the application
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "8080"]
