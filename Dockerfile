FROM	php:fpm-alpine

LABEL	maintainer="https://github.com/hermsi1337"

# Upgrade stuff
RUN apk update && \
    apk upgrade

# Install build dependencies
RUN docker-php-source extract           \
    && apk add --no-cache               \
        --virtual .build-dependencies   \
            $PHPIZE_DEPS                \
            zlib-dev                    \
            cyrus-sasl-dev              \
            git                         \
            autoconf                    \
            g++                         \
            libtool                     \
            make                        \
            pcre-dev

# Install additional stuff needed for modules
RUN apk add --no-cache      \
        tini                \
        libintl             \
        icu                 \
        icu-dev             \
        libxml2-dev         \
        postgresql-dev      \
        freetype-dev        \
        libjpeg-turbo-dev   \
        libmcrypt-dev       \
        libpng-dev          \
        gmp                 \
        gmp-dev             \
        libmemcached-dev    \
        imagemagick-dev     \
        libssh2             \
        libssh2-dev

# Download source code for redis
ENV PHPREDIS_VERSION="4.0.1"

RUN curl -L -o /tmp/redis.tar.gz                                                \
    "https://github.com/phpredis/phpredis/archive/${PHPREDIS_VERSION}.tar.gz"   \
    && tar xfz /tmp/redis.tar.gz                                                \
    && rm -r /tmp/redis.tar.gz                                                  \
    && mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis

# Download sources for memcached
RUN git clone --branch php7 https://github.com/php-memcached-dev/php-memcached.git /usr/src/php/ext/memcached/  \
    && docker-php-ext-configure memcached

# Configure gd
RUN docker-php-ext-configure gd         \
    --with-freetype-dir=/usr/include/   \
    --with-jpeg-dir=/usr/include/

RUN docker-php-ext-install -j"$(getconf _NPROCESSORS_ONLN)" \
        intl                                                \
        zip                                                 \
        soap                                                \
        mysqli                                              \
        pdo                                                 \
        pdo_mysql                                           \
        pdo_pgsql                                           \
        gmp                                                 \
        redis                                               \
        iconv                                               \
        gd                                                  \
        memcached

# Install PECL extensions
RUN pecl install                \
        apcu imagick ssh2-1     \
    && docker-php-ext-enable    \
        apcu imagick ssh2

# set recommended opcache PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
COPY conf.d/00-opcache-recommended.ini /usr/local/etc/php/conf.d/00-opcache-recommended.ini

# set recommended apcu PHP.ini settings
# see https://secure.php.net/manual/en/apcu.configuration.php
COPY    conf.d/00-apcu-recommended.ini /usr/local/etc/php/conf.d/00-apcu-recommended.ini

RUN sed -i -e 's/listen.*/listen = 0.0.0.0:9000/' /usr/local/etc/php-fpm.conf

RUN echo "expose_php=0" > /usr/local/etc/php/php.ini

# Clean up
RUN apk del .build-dependencies \
    && docker-php-source delete \
    && rm -rf /tmp/* /var/cache/apk/*

CMD ["php-fpm"]
