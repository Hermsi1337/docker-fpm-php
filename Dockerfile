# syntax=docker/dockerfile:1
#
# Batteries-included PHP-FPM on Alpine.
#
# A single, parameterised Dockerfile builds every PHP version and every
# variant. Pick the PHP version via the PHP_VERSION build-arg and the variant
# via the build target:
#
#   docker build --build-arg PHP_VERSION=8.4 --target standard -t fpm-php:8.4 .
#   docker build --build-arg PHP_VERSION=8.4 --target composer -t fpm-php:8.4-composer .
#   docker build --build-arg PHP_VERSION=8.4 --target ioncube  -t fpm-php:8.4-ioncube .
#
# Extensions are installed with mlocati/docker-php-extension-installer, which
# resolves the correct build/runtime dependencies for every supported PHP
# version instead of compiling everything by hand.

ARG PHP_VERSION=8.5

########################################################################
# base: shared layer with all bundled extensions and recommended config
########################################################################
FROM php:${PHP_VERSION}-fpm-alpine AS base

LABEL maintainer="https://github.com/hermsi1337"
LABEL org.opencontainers.image.title="alpine-fpm-php"
LABEL org.opencontainers.image.description="Batteries-included PHP-FPM on Alpine"
LABEL org.opencontainers.image.source="https://github.com/Hermsi1337/docker-fpm-php"
LABEL org.opencontainers.image.licenses="MIT"

# The batteries-included extension set is NOT hard-coded here. It lives in
# versions.yaml (the single source of truth) and is rendered in via the
# PHP_EXTENSIONS build-arg by build-local.sh and the CI workflow. There is
# deliberately no default value: a bare build must not silently produce an
# image without extensions.
ARG PHP_EXTENSIONS

# Fail fast with a clear message when the extension list was not supplied.
RUN set -eux; \
    if [ -z "${PHP_EXTENSIONS:-}" ]; then \
        echo "ERROR: PHP_EXTENSIONS build-arg is empty." >&2; \
        echo "       Pass --build-arg PHP_EXTENSIONS=\"...\"; see versions.yaml / build-local.sh." >&2; \
        exit 1; \
    fi

# tini is kept available for users who wire it up as an init process.
RUN set -eux; \
    apk add --no-cache tini

# Pull in the extension installer (pinned to its latest published release) and
# install the requested set in a single, dependency-aware pass.
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN set -eux; \
    chmod +x /usr/local/bin/install-php-extensions; \
    install-php-extensions ${PHP_EXTENSIONS}

# Recommended php.ini snippets (opcache, apcu, expose_php=Off).
# https://www.php.net/manual/en/opcache.installation.php
# https://www.php.net/manual/en/apcu.configuration.php
COPY conf.d/ /usr/local/etc/php/conf.d/

CMD ["php-fpm"]

########################################################################
# composer: base + Composer 2 (installer picks a compatible release)
########################################################################
FROM base AS composer

RUN set -eux; \
    install-php-extensions @composer

########################################################################
# ioncube: base + ionCube loader (x86_64 only; no loader exists for 8.0)
########################################################################
FROM base AS ioncube

RUN set -eux; \
    install-php-extensions ioncube_loader

########################################################################
# standard: default target, identical to base (kept last so a plain
# `docker build` with no --target yields the batteries-included image)
########################################################################
FROM base AS standard
