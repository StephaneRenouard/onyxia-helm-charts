#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_TAG="${IMAGE_TAG:-0.1.5}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}"
IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST:-}"   # ex: harbor.lan
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-}"           # ex: premyom
IMAGE_NAME="${IMAGE_NAME:-onyxia-s3-explorer}"   # image name (sans namespace)
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
FILEBROWSER_VERSION="${FILEBROWSER_VERSION:-2.53.1}"
DOCKER_NO_CACHE="${DOCKER_NO_CACHE:-true}"
DOCKER_PULL="${DOCKER_PULL:-true}"
BUILD_GIT_COMMIT="${BUILD_GIT_COMMIT:-unknown}"
BUILD_IMAGE_SOURCE_SHA="${BUILD_IMAGE_SOURCE_SHA:-unknown}"

if [[ -z "${IMAGE_REPOSITORY}" ]]; then
  if [[ -n "${IMAGE_REGISTRY_HOST}" ]]; then
    if [[ -z "${IMAGE_NAMESPACE}" ]]; then
      echo "IMAGE_NAMESPACE requis quand IMAGE_REGISTRY_HOST est défini (ex: premyom)." >&2
      exit 1
    fi
    IMAGE_REPOSITORY="${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}"
  else
    IMAGE_REPOSITORY="stephanerenouard/${IMAGE_NAME}"
  fi
fi

BUILD_FLAGS=()
if [[ "${DOCKER_NO_CACHE}" == "true" ]]; then
  BUILD_FLAGS+=(--no-cache)
fi
if [[ "${DOCKER_PULL}" == "true" ]]; then
  BUILD_FLAGS+=(--pull)
fi

docker build \
  "${BUILD_FLAGS[@]}" \
  --label "io.premyom.git-commit=${BUILD_GIT_COMMIT}" \
  --label "io.premyom.image-source-sha=${BUILD_IMAGE_SOURCE_SHA}" \
  --build-arg "FILEBROWSER_VERSION=${FILEBROWSER_VERSION}" \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
  -f "${DOCKERFILE}" \
  ../..
