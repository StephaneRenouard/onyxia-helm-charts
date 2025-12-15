#!/usr/bin/env bash
set -euo pipefail

CHART_VERSION="${IMAGE_TAG:-$(sed -n 's/^version:[[:space:]]*//p' Chart.yaml | head -n 1)}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-stephanerenouard/onyxia-vscode}"
DOCKERFILE="${DOCKERFILE:-premyom-vscode-python.dockerfile}"

docker login
docker build -t "${IMAGE_REPOSITORY}:${CHART_VERSION}" -f "${DOCKERFILE}" .

