# syntax = docker/dockerfile:1

# 1. Etapa base con la versión de Ruby de tus logs
FROM ruby:3.4.4-slim AS base

WORKDIR /rails

# Configuración de producción
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# 2. Etapa de construcción (Build)
# Aquí instalamos las dependencias necesarias para compilar gemas (build-essential, git, etc.)
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    pkg-config \
    curl \
    libvips \
    node-gyp \
    python-is-python3

# Instalación de Node.js y Yarn (necesarios para assets)
ARG NODE_VERSION=20.11.1
ARG YARN_VERSION=1.22.19
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Instalación de gemas
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copiar el código y precompilar assets
COPY . .
RUN if [ -f bin/rails ]; then \
      SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile; \
    fi

# 3. Etapa final (Runner)
FROM base

# Instalación de dependencias de tiempo de ejecución únicamente
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copiar gemas y artefactos construidos
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Usuario no-root por seguridad
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Script de entrada
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
