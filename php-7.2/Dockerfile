ARG     PHP_VERSION="${PHP_VERSION:-7.2.8}"
FROM	php:${PHP_VERSION}-fpm-alpine

LABEL	maintainer="https://github.com/hermsi1337"

ARG     PHPREDIS_VERSION="${PHPREDIS_VERSION:-4.2.0}"
ENV     PHPREDIS_VERSION="${PHPREDIS_VERSION}"

ADD     http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz /tmp/
ADD     https://github.com/phpredis/phpredis/archive/${PHPREDIS_VERSION}.tar.gz /tmp/

RUN     apk update                       && \
        \
        apk upgrade                      && \
        \
        docker-php-source extract        && \
        \
        apk add --no-cache                  \
            --virtual .build-dependencies   \
                $PHPIZE_DEPS                \
                zlib-dev                    \
                cyrus-sasl-dev              \
                git                         \
                autoconf                    \
                g++                         \
                libtool                     \
                make                        \
                pcre-dev                 && \
        \
        apk add --no-cache                  \
            tini                            \
            libintl                         \
            icu                             \
            icu-dev                         \
            libxml2-dev                     \
            postgresql-dev                  \
            freetype-dev                    \
            libjpeg-turbo-dev               \
            libpng-dev                      \
            gmp                             \
            gmp-dev                         \
            libmemcached-dev                \
            imagemagick-dev                 \
            libssh2                         \
            libssh2-dev                     \
            libxslt-dev                  && \
        \
        tar xfz /tmp/${PHPREDIS_VERSION}.tar.gz   && \
        \
        mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis    && \
        \
        git clone https://github.com/php-memcached-dev/php-memcached.git /usr/src/php/ext/memcached/    && \
        \
        docker-php-ext-configure memcached      &&  \
        \
        docker-php-ext-configure gd                 \
            --with-freetype-dir=/usr/include/       \
            --with-jpeg-dir=/usr/include/       &&  \
        \
        docker-php-ext-install -j"$(getconf _NPROCESSORS_ONLN)" \
            intl                                                \
            bcmath                                              \
            xsl                                                 \
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
            memcached                                       &&  \
        \
        tar -xvzf /tmp/ioncube_loaders_lin_x86-64.tar.gz -C /tmp/   &&  \
        \
        mkdir -p /usr/local/php/ext/ioncube                         &&  \
        \
        cp  /tmp/ioncube/ioncube_loader_lin_${PHP_VERSION%.*}.so        \
            /usr/local/php/ext/ioncube/ioncube_loader.so            &&  \
        \
        docker-php-ext-configure opcache --enable-opcache           &&  \
        \
        docker-php-ext-install opcache                              &&  \
        \
        pecl install                                                    \
            apcu imagick ssh2-1.1.2                                 &&  \
        \
        docker-php-ext-enable                                           \
            apcu imagick ssh2                                       &&  \
        \
        echo "expose_php=0" > /usr/local/etc/php/php.ini            &&  \
        \
        apk del .build-dependencies                                 &&  \
        \
        docker-php-source delete                                    &&  \
        \
        rm -rf /tmp/* /var/cache/apk/*

# set recommended PHP.ini settings
# https://secure.php.net/manual/en/opcache.installation.php
# https://secure.php.net/manual/en/apcu.configuration.php
# also, enable ioncube
COPY    conf.d/* /usr/local/etc/php/conf.d/

CMD     ["php-fpm"]
