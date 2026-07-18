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
[`versions.yaml`](./versions.yaml). Extensions are installed with
[`mlocati/docker-php-extension-installer`](https://github.com/mlocati/docker-php-extension-installer)
instead of being hand-compiled. The two museum pieces, PHP 5.6 and 7.0, are
the exception: the installer needs PHP 7.1+ on Alpine, so they build from
[`Dockerfile.legacy`](./Dockerfile.legacy) with hard-pinned PECL releases.

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
| `7.0` | `amd64`         | `amd64`         | `amd64`    | EOL &mdash; legacy build |
| `5.6` | `amd64`         | `amd64`         | `amd64`    | EOL &mdash; legacy build |

> **EOL versions are built best-effort on frozen base images.** PHP 8.1 and
> everything below it no longer receives upstream security fixes, and the
> underlying `php:<x.y>-fpm-alpine` base images are frozen. These tags are
> provided for legacy workloads **with no security guarantees** &mdash; do not
> ship them to production. The whole lineup is rebuilt weekly: supported
> versions (PHP 8.2+) pick up Alpine package updates, EOL versions at least
> get a current CA trust store (see [CA bundle
> freshness](#ca-bundle-freshness)).
>
> **PHP 7.0 and 5.6 are museum pieces.** Their base images (7.0.33 on Alpine
> 3.7, 5.6.40 on Alpine 3.8) have been frozen since **January 2019** &mdash;
> that is years of unpatched OS packages, OpenSSL/LibreSSL and PHP CVEs baked
> in forever. They exist purely to keep ancient legacy workloads running,
> are `amd64`-only, and are built from a separate
> [`Dockerfile.legacy`](./Dockerfile.legacy) with hard-pinned PECL releases
> (the extension installer requires PHP 7.1+).
>
> `ioncube` has no loader for PHP 8.0, so that variant is skipped there. The
> `ioncube` variant is `amd64`-only. On 5.6/7.0 it ships loader **13.3.1**
> &mdash; the newest release that still runs on those frozen bases.

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

This list is **not** hard-coded in the `Dockerfile`; it lives in
[`versions.yaml`](./versions.yaml) and is rendered into the build via the
`PHP_EXTENSIONS` build-arg. See [Extension list &amp; smoke
tests](#extension-list--smoke-tests) below.

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

The `Dockerfile` has no built-in extension list &mdash; it must be supplied via
the `PHP_EXTENSIONS` build-arg (a bare `docker build` fails fast with a hint).
[`build-local.sh`](./build-local.sh) reads the right list for a version out of
[`versions.yaml`](./versions.yaml) and builds the image for you:

```bash
./build-local.sh 8.4                      # standard, linux/amd64
./build-local.sh 8.4 composer             # composer variant
./build-local.sh 8.4 ioncube              # ioncube variant
./build-local.sh 8.4 standard linux/arm64 # cross-build (needs QEMU/binfmt)
./build-local.sh 5.6                      # legacy versions work the same way
```

It needs `bash`, `docker`, `jq` and `yq`. If `yq` is not installed it falls
back to the `mikefarah/yq` container, so a checkout with only Docker present
(e.g. Windows + Git Bash) still works.

If you would rather call Docker yourself, pass both build-args explicitly (the
extension string is whatever `versions.yaml` resolves to for that version):

```bash
docker build --build-arg PHP_VERSION=8.4 \
  --build-arg PHP_EXTENSIONS="apcu bcmath gd ... zip" \
  --target standard -t fpm-php:8.4 .
```

To add or drop a PHP version, edit [`versions.yaml`](./versions.yaml); the CI
matrix is generated from it.

## Extension list &amp; smoke tests

The bundled extension set is maintained in **one place**,
[`versions.yaml`](./versions.yaml):

```yaml
extensions:        # global list, installed on every version/variant
  - apcu
  - bcmath
  # ...
versions:
  - php: "7.2"
    # optional per-version tweaks; effective set is
    # extensions + extensions_add - extensions_remove
    extensions_add:
      - calendar
```

That single source feeds three consumers, so they can never drift apart:

1. the **build** &mdash; the effective list is rendered into the image through
   the `PHP_EXTENSIONS` build-arg (never hard-coded in the `Dockerfile`);
2. **CI** &mdash; the build matrix and the per-build extension list are both
   derived from `versions.yaml`;
3. the **smoke test** &mdash; [`test/smoke.sh`](./test/smoke.sh) reads the same
   list back and asserts every extension is actually present in the built image.

The legacy `Dockerfile.legacy` (PHP 5.6/7.0) necessarily hard-codes its
build recipe; it therefore asserts at build time that the recipe matches the
list rendered from `versions.yaml` and fails fast if the two ever drift.

Every image built in CI is smoke-tested **before** it is pushed. For multi-arch
versions both the `amd64` and the (QEMU-emulated) `arm64` image are built,
loaded and tested first; only then is the multi-arch image pushed.

`test/smoke.sh` verifies, inside the container:

- every expected extension shows up in `php -m` (with the `opcache` &rarr;
  `Zend OPcache` naming handled);
- the running PHP version matches the expected minor;
- `php-fpm -t` reports a valid configuration;
- the variant extras work (`composer --version`; the ionCube loader in
  `php -v`).

Run it locally against an image you built:

```bash
./build-local.sh 8.4 composer
./test/smoke.sh fpm-php:8.4-composer 8.4 composer
```

Like `build-local.sh`, it uses a local `yq` when available and otherwise the
`mikefarah/yq` container.

## CA bundle freshness

The EOL base images are frozen &mdash; and so are their CA trust stores. The
PHP 5.6 base, for example, ships root certificates from 2018/2019, which
predate the ISRG (Let's Encrypt) root rotations: HTTPS calls from PHP against
much of today's web would fail on trust errors alone.

Every image therefore copies the **current CA bundle** out of an
`alpine:latest` donor stage at build time, into **both** locations Alpine
uses:

- `/etc/ssl/certs/ca-certificates.crt` &mdash; read by curl and most CLI tools
- `/etc/ssl/cert.pem` &mdash; the openssl/LibreSSL default that PHP's
  `openssl` streams actually read (on the frozen bases these two files were
  stale *and* different from each other)

The weekly rebuild of the whole lineup refreshes this bundle in every tag, and
`test/smoke.sh` asserts (by sha256, against the same donor) that both paths in
every built image match &mdash; images with a stale store never get pushed.

**Honest limit:** this refreshes the *trusted roots* only. The TLS stack
itself (LibreSSL on the frozen bases) stays as old as the base image &mdash;
no TLS 1.3 on PHP 5.6/7.0, old cipher suites, and none of the OpenSSL fixes
from after the freeze. A current trust store makes those images usable, not
secure.

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
- **PHP 5.6 and 7.0 are back, via a legacy build path** &mdash; the extension
  installer requires PHP 7.1+ on Alpine, so these two build from
  [`Dockerfile.legacy`](./Dockerfile.legacy) (`amd64`-only, frozen 2019 bases,
  pinned PECL releases; see the lineup warning above).
- **`mcrypt` was dropped** (removed from PHP core since 7.2).
- **`ssh2` is now available on every version** (it used to be limited to the
  older releases).
- **Composer is now available** via the `-composer` variant.
- Images are additionally mirrored to `ghcr.io/hermsi1337/fpm-php`.
