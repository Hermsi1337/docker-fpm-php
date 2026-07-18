#!/usr/bin/env bash
#
# Smoke-test a built image against versions.yaml (the single source of truth).
#
# Asserts, inside the container:
#   * `php -m` contains every extension expected for this PHP version
#     (the effective list from versions.yaml: extensions + extensions_add
#      - extensions_remove);
#   * the running PHP version matches the expected minor (e.g. 8.4);
#   * `php-fpm -t` reports a valid configuration;
#   * variant extras: composer -> `composer --version`; ioncube -> the ionCube
#     loader shows up in `php -v`.
#
# Exits non-zero on the first failing image, printing exactly what is missing.
#
# Usage:
#   ./test/smoke.sh <image-ref> <php-version> [variant] [docker-platform]
#
#   image-ref        image to test (must be present in the local docker daemon)
#   php-version      e.g. 8.4, 7.2 (must exist in versions.yaml)
#   variant          standard (default) | composer | ioncube
#   docker-platform  optional, e.g. linux/arm64 -> `docker run --platform ...`
#
# Requires: bash, docker, jq, and either a local `yq` or Docker (mikefarah/yq
# fallback).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
versions_yaml="${here}/../versions.yaml"

image="${1:-}"
php="${2:-}"
variant="${3:-standard}"
platform="${4:-}"

if [ -z "$image" ] || [ -z "$php" ]; then
  echo "Usage: $0 <image-ref> <php-version> [standard|composer|ioncube] [docker-platform]" >&2
  exit 1
fi

run_args=(run --rm)
if [ -n "$platform" ]; then
  run_args+=(--platform "$platform")
fi
drun() { docker "${run_args[@]}" "$image" "$@"; }

# --- read versions.yaml (local yq, else mikefarah/yq container) --------------
yaml_to_json() {
  if command -v yq >/dev/null 2>&1; then
    yq -o=json '.' "$1"
  else
    docker run --rm -i mikefarah/yq -o=json '.' <"$1"
  fi
}
json="$(yaml_to_json "$versions_yaml")"

if ! printf '%s' "$json" | jq -e --arg php "$php" '.versions[] | select(.php == $php)' >/dev/null; then
  echo "ERROR: PHP version '$php' not found in versions.yaml" >&2
  exit 1
fi

# Effective extension list for this version.
mapfile -t expected < <(printf '%s' "$json" | jq -r --arg php "$php" '
  ( [ .versions[] | select(.php == $php) ][0] ) as $v
  | ( ( .extensions + ($v.extensions_add // []) ) - ($v.extensions_remove // []) )
  | unique[]
' | tr -d '\r')

if [ "${#expected[@]}" -eq 0 ]; then
  echo "ERROR: computed an empty extension list for PHP $php" >&2
  exit 1
fi

fail=0
ok()  { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fail=1; }

echo "== smoke test: image=${image} php=${php} variant=${variant}${platform:+ platform=${platform}}"

# --- 1) extensions present in php -m ----------------------------------------
# `php -m` prints module names verbatim; only opcache is renamed ("Zend
# OPcache"). Match case-insensitively on whole lines (verified empirically).
modules="$(drun php -m | tr -d '\r' | tr '[:upper:]' '[:lower:]')"

module_name() {
  case "$1" in
    opcache) printf 'zend opcache' ;;
    *)       printf '%s' "$1" ;;
  esac
}

echo "-- extensions (php -m)"
for ext in "${expected[@]}"; do
  want="$(module_name "$ext")"
  if printf '%s\n' "$modules" | grep -Fxq "$want"; then
    ok "$ext"
  else
    bad "$ext (module '$want' missing from php -m)"
  fi
done

# --- 2) PHP minor matches ----------------------------------------------------
echo "-- php version"
if drun php -r '
    $want = $argv[1];
    $have = PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;
    if ($have !== $want) { fwrite(STDERR, "have $have, want $want\n"); exit(1); }
    fwrite(STDOUT, PHP_VERSION . "\n");
' "$php" >/tmp/smoke_ver.out 2>/tmp/smoke_ver.err; then
  ok "PHP $(cat /tmp/smoke_ver.out)"
else
  bad "version mismatch: $(cat /tmp/smoke_ver.err 2>/dev/null)"
fi

# --- 3) php-fpm config test --------------------------------------------------
echo "-- php-fpm -t"
if drun php-fpm -t >/tmp/smoke_fpm.out 2>&1; then
  ok "php-fpm configuration valid"
else
  bad "php-fpm -t failed:"; cat /tmp/smoke_fpm.out
fi

# --- 4) variant extras -------------------------------------------------------
case "$variant" in
  composer)
    echo "-- composer"
    if drun composer --version >/tmp/smoke_composer.out 2>&1; then
      ok "$(head -1 /tmp/smoke_composer.out)"
    else
      bad "composer --version failed:"; cat /tmp/smoke_composer.out
    fi
    ;;
  ioncube)
    echo "-- ionCube loader"
    if drun php -v 2>/dev/null | grep -qi 'ioncube'; then
      ok "ionCube loader present in php -v"
    else
      bad "ionCube loader not found in php -v"
    fi
    ;;
esac

if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
