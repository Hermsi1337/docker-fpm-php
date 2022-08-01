#!/usr/bin/env bash

set -e

IMAGE_NAME="${IMAGE_NAME:-hermsi/alpine-fpm-php}"

LATEST="8.2"
STABLE="8.1"

BUILD_DIR="${PWD}"
if [[ -n "${CI_PROJECT_DIR}" ]] ; then
  BUILD_DIR="${CI_PROJECT_DIR}"
fi

DIRECTORIES=($(find "${BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -name "php*" | sed -e 's#.*\/\(\)#\1#' | sort))
CHANGED_DIRECTORIES=($(git -C "${BUILD_DIR}" diff HEAD~ --name-only | grep -ioe "php-[0-9+].[0-9+]\|conf.d\|build-images.sh" | sort))

PHPREDIS_VERSION="$(w3m -dump "https://github.com/phpredis/phpredis/tags"  | egrep "^[0-9]+.[0-9]+.[0-9]+(RC[0-9]+)?" | tr -d '\r' | awk '{print $1}' | head -n1)"
PHPREDIS_VERSION_TAG="phpredis${PHPREDIS_VERSION}"

BUILD_ALL_REGEX=".*conf.d.*\|.*build-images.sh.*"

docker_push() {
    unset IMAGE
    IMAGE="${1}"

    echo "# Pushing tag: ${IMAGE##*:}"
    docker push "${IMAGE}" 1>/dev/null
}

if [[ -n "${1}" ]]; then
    TO_BUILD=("${1}")
elif [[ "${#CHANGED_DIRECTORIES[@]}" -eq 0 ]] || [[ $( echo "${CHANGED_DIRECTORIES[@]}" | grep -e "${BUILD_ALL_REGEX}" ) ]]; then
    TO_BUILD=(${DIRECTORIES[*]})
else
    TO_BUILD=(${CHANGED_DIRECTORIES[*]})
fi

echo "# # # # # # # # # # # # # # # # # # # # # # # # #"
echo "# We're building the following realeases now:"
echo "# ${TO_BUILD[@]}"

for PHP_VERSION_DIR in ${TO_BUILD[@]}; do

    echo "# # # # # # # # # # # # # # # # # #"
    echo "# Building: ${PHP_VERSION_DIR}"

    unset FULL_PHP_VERSION_PATH
    FULL_PHP_VERSION_PATH="${BUILD_DIR}/${PHP_VERSION_DIR}"

    unset PHP_VERSION
    PHP_VERSION="${PHP_VERSION_DIR#*-}"

    docker pull "php:${PHP_VERSION}-fpm-alpine"
    unset PATCH_RELEASE_TAG
    PATCH_RELEASE_TAG="$(docker run --rm --entrypoint /usr/bin/env -t "php:${PHP_VERSION}-fpm-alpine" /bin/sh -c 'echo $PHP_VERSION' | tr -d '\r')"

    unset MINOR_RELEASE_TAG
    MINOR_RELEASE_TAG="${PATCH_RELEASE_TAG%.*}"

    unset MAJOR_RELEASE_TAG
    MAJOR_RELEASE_TAG="${MINOR_RELEASE_TAG%.*}"

    unset STABLE_RELEASE_TAG
    STABLE_RELEASE_TAG="stable"

    unset LATEST_RELEASE_TAG
    LATEST_RELEASE_TAG="latest"

    set -x
    docker build \
        --no-cache \
        --pull \
        --build-arg PHP_VERSION="${PATCH_RELEASE_TAG}" \
        --build-arg PHPREDIS_VERSION="${PHPREDIS_VERSION}" \
        --tag "${IMAGE_NAME}:${LATEST_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${LATEST_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}" \
        --tag "${IMAGE_NAME}:${STABLE_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${STABLE_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}" \
        --tag "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}" \
        --tag "${IMAGE_NAME}:${MINOR_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${MINOR_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}" \
        --tag "${IMAGE_NAME}:${PATCH_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${PATCH_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}" \
        --file "${FULL_PHP_VERSION_PATH}/Dockerfile" \
        "${BUILD_DIR}"
    set +x

    if [[ "${CI_COMMIT_REF_SLUG}" == "master" ]]; then

        [[ "${MINOR_RELEASE_TAG}" == "${STABLE}" ]] && docker_push "${IMAGE_NAME}:${STABLE_RELEASE_TAG}" && docker_push "${IMAGE_NAME}:${STABLE_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}"
        [[ "${MINOR_RELEASE_TAG}" == "${LATEST}" ]] && docker_push "${IMAGE_NAME}:${LATEST_RELEASE_TAG}" && docker_push "${IMAGE_NAME}:${LATEST_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}"
        [[ "${MINOR_RELEASE_TAG}" == "${STABLE}" ]] && docker_push "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}" && docker_push "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}"
        docker_push "${IMAGE_NAME}:${MINOR_RELEASE_TAG}"
        docker_push "${IMAGE_NAME}:${MINOR_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}"
        docker_push "${IMAGE_NAME}:${PATCH_RELEASE_TAG}"
        docker_push "${IMAGE_NAME}:${PATCH_RELEASE_TAG}-${PHPREDIS_VERSION_TAG}"

    fi

done

echo "# # # # # # # # # # # # # # # # # # # # # # # # #"
