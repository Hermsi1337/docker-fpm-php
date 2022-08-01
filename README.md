# Make your FPM-PHP fly on Alpine

[![Pulls](https://img.shields.io/docker/pulls/hermsi/alpine-fpm-php?label=hub.docker.com%20pulls&style=flat-square)](https://hub.docker.com/r/hermsi/alpine-fpm-php/)
[![Donate](https://img.shields.io/badge/Donate-PayPal-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=T85UYT37P3YNJ&source=url)

## Overview

This is a Dockerfile/image to build a container for FPM-PHP.
Most of the regular needed modules (apcu, opcache, php-redis, etc.) are built in and configured like suggested on [php.net](https://secure.php.net/).

## Regular builds, automagically

Thanks to [Travis-CI](https://travis-ci.com/) this image is pushed weekly and creates new [tags](https://hub.docker.com/r/hermsi/alpine-fpm-php/tags/) if there are new versions available.

## Tags

For recent tags check [Dockerhub](https://hub.docker.com/r/hermsi/alpine-fpm-php/tags/).
* `8.2`, `latest` (BETA)
* `8.1`, `stable` (SUPPORTED)
* `8.0` (SUPPORTED)
* `7.4` (SECURITY ONLY)
* `7.3` (EOL)
* `7.2` (EOL)
* `7.1` (EOL)
* `7.0` (EOL)

## Features

* intl
* zip
* soap
* mysqli
* pdo
* pdo_mysql
* pdo_pgsql
* mcrypt
* exif
* gd
* iconv
* xsl
* bcmath
* gmp
* php-redis
* memcached
* openssl
* opcache ([configuration reference](https://secure.php.net/manual/en/opcache.installation.php))
* apcu ([configuration reference](https://secure.php.net/manual/en/apcu.configuration.php))
* imagick
* ssh2 (< 7.3)
* ioncube
* mcrypt (< 7.2)

## Basic Usage

This Image is intended to be used along with an external webserver container like apache or nginx.
I personally prefer nginx over apache. If you are interested in how to setup nginx along with this fpm-php image, take a look at [my docker-compose files](https://github.com/Hermsi1337/docker-compose/blob/master/full_php_dev_stack/docker-compose.yml).
