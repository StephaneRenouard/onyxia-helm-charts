#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-stephanerenouard/onyxia-s3-explorer}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
FILEBROWSER_VERSION="${FILEBROWSER_VERSION:-2.32.0}"
DOCKER_LOGIN="${DOCKER_LOGIN:-false}"

if [[ "${DOCKER_LOGIN}" == "true" ]]; then
  docker login
fi

docker build \
  --build-arg "FILEBROWSER_VERSION=${FILEBROWSER_VERSION}" \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
  -f "${DOCKERFILE}" \
  ../..

docker push "${IMAGE_REPOSITORY}:${IMAGE_TAG}"

