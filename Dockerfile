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

# intl, zip, soap
RUN docker-php-ext-install intl zip soap

# mysqli, pdo, pdo_mysql, pdo_pgsql
RUN docker-php-ext-install mysqli pdo pdo_mysql pdo_pgsql

# gd, iconv
RUN docker-php-ext-install -j"$(getconf _NPROCESSORS_ONLN)" iconv \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j"$(getconf _NPROCESSORS_ONLN)" gd

# gmp
RUN docker-php-ext-install gmp

# php-redis
ENV PHPREDIS_VERSION="4.0.1"

RUN curl -L -o /tmp/redis.tar.gz "https://github.com/phpredis/phpredis/archive/${PHPREDIS_VERSION}.tar.gz" \
    && tar xfz /tmp/redis.tar.gz \
    && rm -r /tmp/redis.tar.gz \
    && mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis \
    && docker-php-ext-install redis

# Memcached
RUN git clone --branch php7 https://github.com/php-memcached-dev/php-memcached.git /usr/src/php/ext/memcached/ \
    && docker-php-ext-configure memcached \
    && docker-php-ext-install memcached

# apcu
RUN pecl install apcu \
    && docker-php-ext-enable apcu

# imagick
RUN pecl install imagick \
    && docker-php-ext-enable imagick

# ssh2
RUN pecl install ssh2-1 \
    && docker-php-ext-enable ssh2

# set recommended opcache PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# set recommended apcu PHP.ini settings
# see https://secure.php.net/manual/en/apcu.configuration.php
RUN { \
        echo 'apc.shm_segments=1'; \
        echo 'apc.shm_size=256M'; \
        echo 'apc.num_files_hint=7000'; \
        echo 'apc.user_entries_hint=4096'; \
        echo 'apc.ttl=7200'; \
        echo 'apc.user_ttl=7200'; \
        echo 'apc.gc_ttl=3600'; \
        echo 'apc.max_file_size=1M'; \
        echo 'apc.stat=1'; \
} > /usr/local/etc/php/conf.d/apcu-recommended.ini

RUN sed -i -e 's/listen.*/listen = 0.0.0.0:9000/' /usr/local/etc/php-fpm.conf

RUN echo "expose_php=0" > /usr/local/etc/php/php.ini

# Clean up
RUN apk del .build-dependencies \
    && docker-php-source delete \
    && rm -rf /tmp/* /var/cache/apk/*

CMD ["php-fpm"]
