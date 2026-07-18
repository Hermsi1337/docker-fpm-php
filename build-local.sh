#!/usr/bin/env bash
#
# Build a single image locally, reading the extension list from versions.yaml
# (the single source of truth). This mirrors what CI does so the repo stays
# buildable without any CI at all.
#
# Usage:
#   ./build-local.sh <php-version> [variant] [platform] [tag]
#
#   php-version   e.g. 8.4, 7.2 (must exist in versions.yaml)
#   variant       standard (default) | composer | ioncube
#   platform      linux/amd64 (default) | linux/arm64 | ...
#   tag           image tag to apply (default: fpm-php:<php>[-<variant>])
#
# Requires: bash, docker, and either a local `yq` or Docker (for the
# `mikefarah/yq` fallback) and `jq`.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
versions_yaml="${here}/versions.yaml"

php="${1:-}"
variant="${2:-standard}"
platform="${3:-linux/amd64}"
tag="${4:-}"

if [ -z "$php" ]; then
  echo "Usage: $0 <php-version> [standard|composer|ioncube] [platform] [tag]" >&2
  exit 1
fi

case "$variant" in
  standard | composer | ioncube) ;;
  *) echo "ERROR: unknown variant '$variant' (expected standard|composer|ioncube)" >&2; exit 1 ;;
esac

# --- read versions.yaml -----------------------------------------------------
# Prefer a local yq; fall back to the mikefarah/yq container so this works on a
# bare Windows/Git-Bash checkout where only Docker is installed.
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

# Effective extension list: extensions + extensions_add - extensions_remove.
extensions="$(printf '%s' "$json" | jq -r --arg php "$php" '
  ( [ .versions[] | select(.php == $php) ][0] ) as $v
  | ( ( .extensions + ($v.extensions_add // []) ) - ($v.extensions_remove // []) )
  | unique
  | join(" ")
' | tr -d '\r')"

if [ -z "$extensions" ]; then
  echo "ERROR: computed an empty extension list for PHP $php" >&2
  exit 1
fi

# Which Dockerfile? Versions marked `dockerfile: legacy` (PHP 5.6 / 7.0) build
# from Dockerfile.legacy, everything else from ./Dockerfile.
dockerfile="$(printf '%s' "$json" | jq -r --arg php "$php" '
  ( [ .versions[] | select(.php == $php) ][0].dockerfile // "" )
  | if . == "legacy" then "Dockerfile.legacy" else "Dockerfile" end
' | tr -d '\r')"

if [ -z "$tag" ]; then
  if [ "$variant" = "standard" ]; then
    tag="fpm-php:${php}"
  else
    tag="fpm-php:${php}-${variant}"
  fi
fi

echo "Building ${tag}"
echo "  php=${php} variant=${variant} platform=${platform} dockerfile=${dockerfile}"
echo "  extensions=${extensions}"

docker build \
  --platform "$platform" \
  --target "$variant" \
  --file "${here}/${dockerfile}" \
  --build-arg "PHP_VERSION=${php}" \
  --build-arg "PHP_EXTENSIONS=${extensions}" \
  --load \
  --tag "$tag" \
  "$here"

echo "Built ${tag}"
