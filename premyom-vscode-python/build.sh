#!/usr/bin/env bash
set -euo pipefail

CHART_VERSION="${IMAGE_TAG:-$(sed -n 's/^version:[[:space:]]*//p' Chart.yaml | head -n 1)}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-}"
IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST:-}" # ex: harbor.lan
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-}"         # ex: premyom
IMAGE_NAME="${IMAGE_NAME:-onyxia-vscode}"      # ex: onyxia-vscode
DOCKERFILE="${DOCKERFILE:-premyom-vscode-python.dockerfile}"
DOCKER_LOGIN="${DOCKER_LOGIN:-false}"

if [[ -z "${IMAGE_REPOSITORY}" ]]; then
  if [[ -n "${IMAGE_REGISTRY_HOST}" ]]; then
    if [[ -z "${IMAGE_NAMESPACE}" ]]; then
      echo "IMAGE_NAMESPACE requis quand IMAGE_REGISTRY_HOST est défini (ex: premyom)." >&2
      exit 1
    fi
    IMAGE_REPOSITORY="${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}"
  else
    IMAGE_REPOSITORY="stephanerenouard/onyxia-vscode"
  fi
fi

if [[ "${DOCKER_LOGIN}" == "true" ]]; then
  if [[ -n "${IMAGE_REGISTRY_HOST}" ]]; then
    docker login "${IMAGE_REGISTRY_HOST}"
  else
    docker login
  fi
fi
docker build -t "${IMAGE_REPOSITORY}:${CHART_VERSION}" -f "${DOCKERFILE}" .
