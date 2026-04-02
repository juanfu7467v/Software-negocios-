# syntax=docker/dockerfile:1
# check=error=true

# Asegúrate de que RUBY_VERSION coincida con la versión de Ruby en tu proyecto
ARG RUBY_VERSION=3.4.4
FROM ruby:$RUBY_VERSION-slim AS base

LABEL fly_launch_runtime="rails"

# Directorio de la aplicación
WORKDIR /rails

# Actualizar gemas y bundler
RUN gem update --system --no-document && \
    gem install -N bundler

# Instalar paquetes base necesarios e instalar Node.js de forma más robusta
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client build-essential node-gyp pkg-config python-is-python3 && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pnpm@10.2.0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Configuración del entorno de producción
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production" \
    NODE_ENV="production"


# Etapa de construcción (Build stage)
FROM base AS build

# Instalar dependencias adicionales para compilar gemas
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y git libffi-dev libpq-dev libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Instalar gemas de la aplicación
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Instalar módulos de node usando PNPM
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile

# Copiar el código de la aplicación
COPY . .

# Precompilar bootsnap y assets
RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Etapa final (Final stage)
FROM base

# Instalar paquetes de ejecución
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y imagemagick libvips && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copiar artefactos construidos
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Configurar usuario no-root por seguridad
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R 1000:1000 db log tmp storage
USER 1000:1000

# Entrada del contenedor
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Exponer puerto y comando por defecto
EXPOSE 3000
CMD ["./bin/rails", "server"]
