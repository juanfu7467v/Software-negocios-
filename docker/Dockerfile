# Stage 1: Node.js assets & binaries
FROM node:24-alpine AS node_image

# Stage 2: Builder
FROM ruby:3.4.4-alpine3.21 AS pre-builder

# Arguments & Environment
ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
ARG BUNDLE_WITHOUT="development:test"
ARG RAILS_SERVE_STATIC_FILES=true
ARG RAILS_ENV=production
ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"

ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    BUNDLE_PATH="/gems" \
    BUNDLE_FORCE_RUBY_PLATFORM=1 \
    BUNDLER_VERSION=2.5.16 \
    RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES} \
    NODE_OPTIONS=${NODE_OPTIONS} \
    PNPM_HOME="/root/.local/share/pnpm" \
    PATH="/root/.local/share/pnpm:/usr/local/bin:$PATH"

# Install system dependencies for building
RUN apk update && apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    tzdata \
    git \
    curl \
    libxml2-dev \
    libxslt-dev \
    vips-dev \
    shared-mime-info \
    xz \
    openssl \
    && gem install bundler -v "$BUNDLER_VERSION"

# Copy Node & NPM from node stage
COPY --from=node_image /usr/local/bin/node /usr/local/bin/
COPY --from=node_image /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g pnpm@${PNPM_VERSION}

WORKDIR /app

# Install Ruby Gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local force_ruby_platform true && \
    if [ "$RAILS_ENV" = "production" ]; then \
      bundle config set without 'development test' && \
      bundle install -j $(nproc) -r 3; \
    else \
      bundle install -j $(nproc) -r 3; \
    fi

# Install JS dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy application code
COPY . .

# Precompile assets
RUN if [ "$RAILS_ENV" = "production" ]; then \
    SECRET_KEY_BASE=precompile_placeholder \
    RAILS_LOG_TO_STDOUT=enabled \
    bundle exec rake assets:precompile && \
    rm -rf spec node_modules tmp/cache; \
    fi

# Final cleanup of builder stage
RUN git rev-parse HEAD > /app/.git_sha && \
    rm -rf .git .gitignore /gems/ruby/3.4.0/cache/*.gem && \
    find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete

# Stage 3: Final Production Image
FROM ruby:3.4.4-alpine3.21

ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_PATH="/gems" \
    BUNDLE_FORCE_RUBY_PLATFORM=1 \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=enabled

# Install minimal runtime dependencies
RUN apk update && apk add --no-cache \
    postgresql-client \
    tzdata \
    vips \
    imagemagick \
    ca-certificates \
    openssl

# Copy binaries and library from node stage (required if apps uses ExecJS or tools like MJML)
COPY --from=node_image /usr/local/bin/node /usr/local/bin/
COPY --from=node_image /usr/local/lib/node_modules /usr/local/lib/node_modules

# Copy gems and app from builder
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app

WORKDIR /app

# Ensure log directory exists
RUN mkdir -p /app/log

EXPOSE 3000

# Metadata
LABEL maintainer="Developer"
LABEL version="1.0"

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
