#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_TAG="${IMAGE_TAG:-0.1.9}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-stephanerenouard/onyxia-code-server}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CODE_SERVER_VERSION="${CODE_SERVER_VERSION:-4.106.3}"
DOCKER_LOGIN="${DOCKER_LOGIN:-false}"

if [[ "${DOCKER_LOGIN}" == "true" ]]; then
  docker login
fi

docker build \
  --build-arg "CODE_SERVER_VERSION=${CODE_SERVER_VERSION}" \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
  -f "${DOCKERFILE}" \
  ../..

docker push "${IMAGE_REPOSITORY}:${IMAGE_TAG}"

