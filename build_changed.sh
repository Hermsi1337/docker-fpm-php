#!/usr/bin/env bash

BASE_DIR="${PWD}"
CHANGED_FILES=$(git diff HEAD~ --name-only)
VERSIONS=$(find . -maxdepth 1 -mindepth 1 -not -path '*/\.*' -type d | cut -d '/' -f 2)

echo ""
echo "Changed files in current commit:"
echo ${CHANGED_FILES}
echo ""

for VERSION in ${VERSIONS}; do

    if [[ $(echo "${CHANGED_FILES}" | grep "${VERSION}") ]]; then

        echo "Building ${VERSION%%/} ..."

        VERSION_DIR="${BASE_DIR}/${VERSION}"
        cd ${VERSION_DIR}

        RELEASE_TAG="$(basename ${PWD})"
        RELEASE_IMAGE="${IMAGE_NAME}:${RELEASE_TAG}"

        TMP_IMAGE_TAG="${TRAVIS_BRANCH}-${RELEASE_TAG}"
        TMP_IMAGE="${IMAGE_NAME}:${TMP_IMAGE_TAG}"

        docker build --pull -t "${TMP_IMAGE}" .

        if [[ "${TRAVIS_BRANCH}" == "master" ]]; then

            docker tag "${TMP_IMAGE}" "${RELEASE_IMAGE}"
            docker push "${RELEASE_IMAGE}"

        fi

    fi

done