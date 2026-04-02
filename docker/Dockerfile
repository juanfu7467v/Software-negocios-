# syntax=docker/dockerfile:1
# check=error=true

# 1. Definir versiones base
ARG RUBY_VERSION=3.4.4
ARG NODE_VERSION=22.14.0
FROM ruby:$RUBY_VERSION-slim AS base

LABEL fly_launch_runtime="rails"

WORKDIR /rails

# Instalar dependencias base del sistema
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    postgresql-client \
    pkg-config \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Instalar Node.js de forma robusta (usando nodosource)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    npm install -g pnpm@10.2.0

# Configurar entorno de Ruby
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"

# --- ETAPA DE CONSTRUCCIÓN ---
FROM base AS build

# Instalar paquetes necesarios para compilar gemas y módulos de node
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libffi-dev \
    libpq-dev \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Instalar Gemas de Ruby
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Instalar dependencias de JavaScript
COPY package.json pnpm-lock.yaml* ./ 
# Si no usas pnpm, cambia a: RUN npm install
RUN pnpm install --frozen-lockfile || npm install

# Copiar el resto del código
COPY . .

# Precompilar bootsnap para mejorar velocidad de inicio
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompilar activos (Vite / Asset Pipeline)
# Usamos un Secret Key falso solo para la compilación
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# --- ETAPA FINAL ---
FROM base

# Instalar runtime específico si falta algo
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y imagemagick && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copiar artefactos construidos
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Configurar usuario de ejecución por seguridad
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R 1000:1000 db log tmp
USER 1000:1000

# Entrada al contenedor
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Exponer puerto y comando de inicio
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
