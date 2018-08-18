#!/usr/bin/env bash

set -e

CURRENT="7.2"

DIRECTORIES=($(find "${TRAVIS_BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -name "php*" -o -name "conf.d" | sed -e 's#.*\/\(\)#\1#' | sort))
CHANGED_DIRECTORIES=($(git -C "${TRAVIS_BUILD_DIR}" diff HEAD~ --name-only | grep -ioe "php-[0-9+].[0-9+]\|conf.d" | sort))

exact_version() {

    unset APP
    APP="${1}"
    FILE="${2}"
    
    grep -i "${APP}" "${FILE}" | cut -d '=' -f 2

}

if [[ "${#CHANGED_DIRECTORIES[@]}" -eq 0 ]] || [[ "${CHANGED_DIRECTORIES[@]}" == *"conf.d"* ]] ; then
    TO_BUILD=($(find "${TRAVIS_BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -name "php*" | sed -e 's#.*\/\(\)#\1#' | sort))
else
    TO_BUILD=(${CHANGED_DIRECTORIES})
fi

for PHP_VERSION_DIR in ${TO_BUILD[@]}; do

    echo "# # # # # # # # # # # # # # # #"
    echo "Building ${PHP_VERSION_DIR}"
    echo "# # # # # # # # # # # # # # # #"

    unset FULL_PHP_VERSION_PATH
    FULL_PHP_VERSION_PATH="${TRAVIS_BUILD_DIR}/${PHP_VERSION_DIR}"

    unset VERSION_FILE
    VERSION_FILE="${FULL_PHP_VERSION_PATH}/exact_versions"

    unset PATCH_RELEASE_TAG
    PATCH_RELEASE_TAG="$(exact_version PHP ${VERSION_FILE})"

    unset MINOR_RELEASE_TAG
    MINOR_RELEASE_TAG="${PATCH_RELEASE_TAG%.*}"

    unset MAJOR_RELEASE_TAG
    MAJOR_RELEASE_TAG="${MINOR_RELEASE_TAG%.*}"

    unset PHPREDIS_VERSION
    PHPREDIS_VERSION="$(exact_version PECLREDIS ${VERSION_FILE})"

    docker build \
        --quiet \
        --no-cache \
        --pull \
        --build-arg PHP_VERSION="${PATCH_RELEASE_TAG}" \
        --build-arg PHPREDIS_VERSION="${PHPREDIS_VERSION}" \
        --tag "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${MINOR_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${PATCH_RELEASE_TAG}" \
        --file "${FULL_PHP_VERSION_PATH}/Dockerfile" \
        "${TRAVIS_BUILD_DIR}"

    if [[ "${TRAVIS_BRANCH}" == "master" ]] && [[ "${TRAVIS_PULL_REQUEST}" == "false" ]]; then

        [[ "${MINOR_RELEASE_TAG}" == "${CURRENT}" ]] && docker push "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}"
        docker push "${IMAGE_NAME}:${MINOR_RELEASE_TAG}"
        docker push "${IMAGE_NAME}:${PATCH_RELEASE_TAG}"

    fi

done