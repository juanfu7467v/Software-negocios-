# syntax=docker/dockerfile:1
# check=error=true

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.4
FROM ruby:$RUBY_VERSION-slim AS base

LABEL fly_launch_runtime="rails"

# Rails app lives here
WORKDIR /rails

# Install base packages needed for the app and nodejs installation
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    gnupg \
    libjemalloc2 \
    libvips \
    postgresql-client \
    build-essential \
    git \
    pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Update gems and install specific Bundler version from Gemfile.lock
RUN gem update --system --no-document && \
    gem install -N bundler

# Set production environment
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production" \
    NODE_ENV="production"

# Install Node.js using NodeSource (more reliable than node-build)
# Using Node 22.x as it is the current stable LTS
ARG NODE_MAJOR=22
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install nodejs -y && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm (Chatwoot uses pnpm as seen in the lockfile)
ARG PNPM_VERSION=10.2.0
RUN npm install -g pnpm@${PNPM_VERSION}

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    libpq-dev \
    libyaml-dev \
    libffi-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile || pnpm install

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Final stage for app image
FROM base AS final

# Copy built artifacts: gems, node_modules, and application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Ensure the application has permissions to write to tmp and log
RUN mkdir -p tmp/pids log storage && \
    chmod -R 777 tmp log storage

# Deployment settings
EXPOSE 3000

# Start the server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
