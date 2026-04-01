# syntax=docker/dockerfile:1
# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.4
FROM ruby:$RUBY_VERSION-slim AS base

LABEL fly_launch_runtime="rails"

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"

# Install base packages needed for the app
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl build-essential git libvips postgresql-client

# Install Node.js
ARG NODE_VERSION="24.13.0"
ARG PNPM_VERSION="10.2.0"
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    rm -rf /tmp/node-build-master
ENV PATH=/usr/local/node/bin:$PATH

# Install pnpm
RUN npm install -g pnpm@${PNPM_VERSION}

# Update gems and bundler
RUN gem update --system --no-document && \
    gem install -N bundler

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install node modules
COPY package.json pnpm-lock.yaml ./
RUN pnpm install

# Copy application code
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE=precompile_placeholder bundle exec rake assets:precompile

# Final stage for app deployment
FROM base AS final

# Copy built artifacts
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run the application
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
