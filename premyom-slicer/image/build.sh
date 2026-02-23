#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}"
IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST:-}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-}"
IMAGE_NAME="${IMAGE_NAME:-onyxia-slicer}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
SLICER_VERSION="${SLICER_VERSION:-5.8}"
SLICER_DOWNLOAD_URL="${SLICER_DOWNLOAD_URL:-}"

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

docker build \
  --build-arg "SLICER_VERSION=${SLICER_VERSION}" \
  --build-arg "SLICER_DOWNLOAD_URL=${SLICER_DOWNLOAD_URL}" \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
  -f "${DOCKERFILE}" \
  ../..
