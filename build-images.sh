#!/usr/bin/env bash

set -e

LATEST="7.3"
STABLE="7.3"
README_URL="http://php.net/downloads.php"

END_OF_LIFE_VERSIONS=("7.0")

DIRECTORIES=($(find "${TRAVIS_BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -name "php*" -o -name "conf.d" | sed -e 's#.*\/\(\)#\1#' | sort))
CHANGED_DIRECTORIES=($(git -C "${TRAVIS_BUILD_DIR}" diff HEAD~ --name-only | grep -ioe "php-[0-9+].[0-9+]\|conf.d\|build-images.sh" | sort))

BUILD_ALL_REGEX=".*conf.d.*\|.*build-images.sh.*"

exact_version() {

    unset APP
    APP="${1}"
    FILE="${2}"

    grep -i "${APP}" "${FILE}" | cut -d '=' -f 2

}

docker_push() {

    unset IMAGE
    IMAGE="${1}"

    echo "# Pushing tag: ${IMAGE##*:}"
    docker push "${IMAGE}" 1>/dev/null
}

if [[ "${#CHANGED_DIRECTORIES[@]}" -eq 0 ]] || [[ $( echo "${CHANGED_DIRECTORIES[@]}" | grep -e "${BUILD_ALL_REGEX}" ) ]]; then
    TO_BUILD=($(find "${TRAVIS_BUILD_DIR}" -maxdepth 1 -mindepth 1 -type d -name "php*" | sed -e 's#.*\/\(\)#\1#' | sort))
else
    TO_BUILD=(${CHANGED_DIRECTORIES})
fi

echo "# # # # # # # # # # # # # # # # # # # # # # # # #"
echo "# We're building the following realeases now:"
echo "# ${TO_BUILD[@]}"

for PHP_VERSION_DIR in ${TO_BUILD[@]}; do

    unset FULL_PHP_VERSION_PATH
    FULL_PHP_VERSION_PATH="${TRAVIS_BUILD_DIR}/${PHP_VERSION_DIR}"

    unset VERSION_FILE
    VERSION_FILE="${FULL_PHP_VERSION_PATH}/exact_versions"

    for EOL in ${END_OF_LIFE_VERSIONS[@]} ; do
        if [[ "${PHP_VERSION_DIR##*-}" = "${EOL}" ]]
            continue 2
        fi
    for

    unset PATCH_RELEASE_TAG
    PATCH_RELEASE_TAG="$(w3m -dump "http://php.net/downloads.php" | grep -i "${PHP_VERSION_DIR##*-}" | grep -i "changelog" | awk '{print $4}')"

    unset MINOR_RELEASE_TAG
    MINOR_RELEASE_TAG="${PATCH_RELEASE_TAG%.*}"

    unset MAJOR_RELEASE_TAG
    MAJOR_RELEASE_TAG="${MINOR_RELEASE_TAG%.*}"

    unset STABLE_RELEASE_TAG
    STABLE_RELEASE_TAG="stable"

    unset LATEST_RELEASE_TAG
    LATEST_RELEASE_TAG="latest"

    unset PHPREDIS_VERSION
    PHPREDIS_VERSION="$(exact_version PECLREDIS ${VERSION_FILE})"

    echo "# # # # # # # # # # # # # # # # # #"
    echo "# Building: ${PHP_VERSION_DIR}"

    set -x
    docker build \
        --quiet \
        --no-cache \
        --pull \
        --build-arg PHP_VERSION="${PATCH_RELEASE_TAG}" \
        --build-arg PHPREDIS_VERSION="${PHPREDIS_VERSION}" \
        --tag "${IMAGE_NAME}:${LATEST_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${STABLE_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${MINOR_RELEASE_TAG}" \
        --tag "${IMAGE_NAME}:${PATCH_RELEASE_TAG}" \
        --file "${FULL_PHP_VERSION_PATH}/Dockerfile" \
        "${TRAVIS_BUILD_DIR}" 1>/dev/null
    set +x

    if [[ "${TRAVIS_BRANCH}" == "master" ]] && [[ "${TRAVIS_PULL_REQUEST}" == "false" ]]; then

        [[ "${MINOR_RELEASE_TAG}" == "${STABLE}" ]] && docker_push "${IMAGE_NAME}:${STABLE_RELEASE_TAG}"
        [[ "${MINOR_RELEASE_TAG}" == "${LATEST}" ]] && docker_push "${IMAGE_NAME}:${LATEST_RELEASE_TAG}"
        [[ "${MINOR_RELEASE_TAG}" == "${STABLE}" ]] && docker_push "${IMAGE_NAME}:${MAJOR_RELEASE_TAG}"
        docker_push "${IMAGE_NAME}:${MINOR_RELEASE_TAG}"
        docker_push "${IMAGE_NAME}:${PATCH_RELEASE_TAG}"

    fi

done

echo "# # # # # # # # # # # # # # # # # # # # # # # # #"
