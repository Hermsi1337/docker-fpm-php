# Batteries-included PHP-FPM on Alpine

[![build](https://github.com/Hermsi1337/docker-fpm-php/actions/workflows/build.yml/badge.svg)](https://github.com/Hermsi1337/docker-fpm-php/actions/workflows/build.yml)
[![Pulls](https://img.shields.io/docker/pulls/hermsi/alpine-fpm-php?style=flat-square)](https://hub.docker.com/r/hermsi/alpine-fpm-php/)
[![Stars](https://img.shields.io/docker/stars/hermsi/alpine-fpm-php?style=flat-square)](https://hub.docker.com/r/hermsi/alpine-fpm-php/)
[![Image size](https://img.shields.io/docker/image-size/hermsi/alpine-fpm-php/latest?style=flat-square)](https://hub.docker.com/r/hermsi/alpine-fpm-php/)
[![Donate](https://img.shields.io/badge/Donate-PayPal-yellow.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=T85UYT37P3YNJ&source=url)

A small PHP-FPM image on Alpine with all the extensions you usually end up
adding anyway (intl, gd, imagick, redis, memcached, apcu, opcache, the PDO
drivers, and more) already baked in and configured to sensible defaults.

The whole lineup is produced from **one parameterised
[`Dockerfile`](./Dockerfile)** and a maintained
[`versions.json`](./versions.json). Extensions are installed with
[`mlocati/docker-php-extension-installer`](https://github.com/mlocati/docker-php-extension-installer)
instead of being hand-compiled.

## Images

Images are published to two registries:

| Registry  | Image                                                                                  |
| --------- | -------------------------------------------------------------------------------------- |
| Docker Hub | [`hermsi/alpine-fpm-php`](https://hub.docker.com/r/hermsi/alpine-fpm-php)              |
| GHCR      | [`ghcr.io/hermsi1337/fpm-php`](https://github.com/Hermsi1337/docker-fpm-php/pkgs/container/fpm-php) |

## Lineup

| PHP   | Standard        | `-composer`     | `-ioncube` | Support status         |
| ----- | --------------- | --------------- | ---------- | ---------------------- |
| `8.5` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | Supported (`latest`)   |
| `8.4` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | Supported              |
| `8.3` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | Supported (security)   |
| `8.2` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | Supported (security)   |
| `8.1` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | EOL &mdash; best-effort |
| `8.0` | `amd64`,`arm64` | `amd64`,`arm64` | &mdash;    | EOL &mdash; best-effort |
| `7.4` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | EOL &mdash; best-effort |
| `7.3` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | EOL &mdash; best-effort |
| `7.2` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | EOL &mdash; best-effort |
| `7.1` | `amd64`,`arm64` | `amd64`,`arm64` | `amd64`    | EOL &mdash; best-effort |

> **EOL versions are built best-effort on frozen base images.** PHP 8.1 and
> everything below it no longer receives upstream security fixes, and the
> underlying `php:<x.y>-fpm-alpine` base images are frozen. These tags are
> provided for legacy workloads **with no security guarantees** &mdash; do not
> ship them to production. Only the supported versions (PHP 8.2+) are rebuilt
> weekly to pick up Alpine package updates.
>
> `ioncube` has no loader for PHP 8.0, so that variant is skipped there. The
> `ioncube` variant is `amd64`-only.

## Tags

For every version in the lineup:

- `<X.Y>` &mdash; e.g. `8.4` (standard variant, multi-arch)
- `<X.Y>-composer` &mdash; standard plus [Composer 2](https://getcomposer.org/)
- `<X.Y>-ioncube` &mdash; standard plus the [ionCube loader](https://www.ioncube.com/) (`amd64` only)

The newest GA release additionally gets the moving tags `latest`,
`latest-composer` and `latest-ioncube`.

The `<X.Y>` tags roll forward to the newest patch release of that branch
(inherited from the upstream base image); there are no per-patch tags to pin.

## Bundled extensions

`apcu`, `bcmath`, `exif`, `gd`, `gmp`, `imagick`, `intl`, `memcached`,
`mysqli`, `opcache`, `pdo_mysql`, `pdo_pgsql`, `redis`, `soap`, `ssh2`, `xsl`,
`zip` &mdash; on top of everything already present in the official
`php:<x.y>-fpm-alpine` base image (`openssl`, `iconv`, `pdo`, ...).

`opcache` and `apcu` ship with the recommended tuning from
[`conf.d/`](./conf.d), and `expose_php` is turned off.

## Usage

This image is meant to sit behind a webserver container such as nginx. A
ready-to-use `docker-compose` setup lives in
[Hermsi1337/docker-compose](https://github.com/Hermsi1337/docker-compose/blob/master/full_php_dev_stack/docker-compose.yml).

```bash
docker run --rm hermsi/alpine-fpm-php:8.4 php -v
docker run --rm hermsi/alpine-fpm-php:8.4-composer composer --version
```

## Building locally

```bash
# standard image
docker build --build-arg PHP_VERSION=8.4 --target standard -t fpm-php:8.4 .

# composer / ioncube variants
docker build --build-arg PHP_VERSION=8.4 --target composer -t fpm-php:8.4-composer .
docker build --build-arg PHP_VERSION=8.4 --target ioncube  -t fpm-php:8.4-ioncube .
```

To add or drop a PHP version, edit [`versions.json`](./versions.json); the CI
matrix is generated from it.

## Migrating from the old tag scheme

The repository was rebuilt from scratch. A few things changed that may affect
existing users:

- **`latest` now points to the newest GA release** (PHP 8.5) instead of the
  old 8.0 pre-release.
- **`stable`, major-only (`7`, `8`) and per-patch (`7.4.2`) tags are gone.**
  Pin a `<X.Y>` tag instead.
- **The `-phpredis<version>` tags are gone.** `redis` is bundled; there is no
  version suffix.
- **ionCube moved to its own `-ioncube` variant.** It is no longer enabled in
  the standard image on any version (previously it was inconsistently baked
  into some 7.x images).
- **PHP 5.6 and 7.0 were dropped** &mdash; the extension installer requires PHP
  7.1+ on Alpine.
- **`mcrypt` was dropped** (removed from PHP core since 7.2).
- **`ssh2` is now available on every version** (it used to be limited to the
  older releases).
- **Composer is now available** via the `-composer` variant.
- Images are additionally mirrored to `ghcr.io/hermsi1337/fpm-php`.
