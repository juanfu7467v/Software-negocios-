# syntax = docker/dockerfile:1

# 1. Etapa base
FROM ruby:3.4.4-slim AS base

WORKDIR /rails

# Instalación de dependencias básicas y actualización de Bundler
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Configuración de producción
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# 2. Etapa de construcción (Build)
FROM base AS build

# Dependencias para compilar gemas y assets
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    pkg-config \
    curl \
    libvips \
    node-gyp \
    python-is-python3 \
    unzip

# Instalación de Node.js y Yarn
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

# Copiar gemas y artefactos construidos desde la etapa 'build'
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Configuración de seguridad: Usuario no-root
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Script de entrada
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
