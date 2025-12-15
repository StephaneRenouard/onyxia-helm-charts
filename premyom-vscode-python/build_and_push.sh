set -euo pipefail

CHART_VERSION="${IMAGE_TAG:-$(awk -F': ' '$1==\"version\"{print $2; exit}' Chart.yaml)}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-stephanerenouard/onyxia-vscode}"
DOCKERFILE="${DOCKERFILE:-premyom-vscode-python.dockerfile}"

docker login
docker build -t "${IMAGE_REPOSITORY}:${CHART_VERSION}" -f "${DOCKERFILE}" .
docker push "${IMAGE_REPOSITORY}:${CHART_VERSION}"



