# syntax=docker/dockerfile:1
# check=error=true

# Asegúrate de que RUBY_VERSION coincida con la de tu .ruby-version
ARG RUBY_VERSION=3.4.4
FROM ruby:$RUBY_VERSION-slim AS base

LABEL fly_launch_runtime="rails"

# Directorio de la aplicación
WORKDIR /rails

# Actualizar gemas y bundler
RUN gem update --system --no-document && \
    gem install -N bundler

# Instalar dependencias base y Node.js usando el repositorio oficial de Nodesource
# Se cambia "24.x" por "22" (LTS actual) o puedes usar "23" si necesitas lo último.
# El error original era porque node-build no encontraba "24.x".
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl gnupg libjemalloc2 libvips postgresql-client && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update -qq && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Instalar PNPM (visto en tu package.json)
RUN npm install -g pnpm

# Configuración de entorno de producción
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production" \
    NODE_ENV="production"


# Etapa intermedia para construir gemas y activos
FROM base AS build

# Instalar paquetes necesarios para compilar extensiones nativas
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libffi-dev libpq-dev libyaml-dev pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Instalar gemas de la aplicación
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Instalar dependencias de Node usando PNPM (según tu package.json)
COPY package.json pnpm-lock.yaml* ./ 
RUN pnpm install --frozen-lockfile

# Copiar el resto del código
COPY . .

# Precompilar bootsnap para un arranque más rápido
RUN bundle exec bootsnap precompile app/ lib/

# Precompilar activos de Rails (Vite)
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Etapa final
FROM base

# Instalar paquetes de tiempo de ejecución
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

# Script de entrada
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Puerto por defecto
EXPOSE 3000

# Comando de inicio
CMD ["./bin/rails", "server"]
