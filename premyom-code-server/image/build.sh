#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_TAG="${IMAGE_TAG:-0.1.9}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}"
IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST:-}"   # ex: harbor.lan
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-}"           # ex: premyom
IMAGE_NAME="${IMAGE_NAME:-onyxia-code-server}"   # image name (sans namespace)
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CODE_SERVER_VERSION="${CODE_SERVER_VERSION:-4.106.3}"

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
  --build-arg "CODE_SERVER_VERSION=${CODE_SERVER_VERSION}" \
  -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
  -f "${DOCKERFILE}" \
  ../..
