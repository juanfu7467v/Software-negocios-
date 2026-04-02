# syntax=docker/dockerfile:1
# check=error=true

# Versiones de Ruby y Node sincronizadas con tu Gemfile y package.json
ARG RUBY_VERSION=3.4.4
ARG NODE_VERSION=22.14.0
ARG PNPM_VERSION=10.2.0

FROM ruby:$RUBY_VERSION-slim AS base

LABEL fly_launch_runtime="rails"

WORKDIR /rails

# Instalación de dependencias base y herramientas de sistema
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    libpq5 \
    libglib2.0-0 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Configuración de variables de entorno de producción
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production" \
    NODE_ENV="production"

# --- Etapa de construcción ---
FROM base AS build

# Instalar dependencias necesarias para compilar gemas y módulos de node
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libffi-dev \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    python-is-python3 \
    libglib2.0-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Instalar Node.js y PNPM copiando desde imágenes oficiales (más rápido y seguro)
COPY --from=node:22.14.0-slim /usr/local/bin /usr/local/bin
COPY --from=node:22.14.0-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN npm install -g pnpm@${PNPM_VERSION}

# Instalar Gemas de Ruby
COPY Gemfile Gemfile.lock ./
RUN gem update --system --no-document && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Instalar dependencias de Node.js con PNPM
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile --prod=false

# Copiar el resto del código y preparar la app
COPY . .

# Precompilar bootsnap y activos
RUN bundle exec bootsnap precompile app/ lib/
RUN chmod +x bin/* && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# --- Etapa Final ---
FROM base

# Instalar librerías de tiempo de ejecución faltantes
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y imagemagick && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copiar artefactos construidos
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Configuración de usuario no-root para seguridad
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R 1000:1000 db log tmp storage
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
