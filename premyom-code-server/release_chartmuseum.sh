#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${REPO_DIR}/premyom-code-server"
IMAGE_DIR="${CHART_DIR}/image"

IMG_TAG="${IMG_TAG:-0.1.21}"
CHART_VERSION="${CHART_VERSION:-0.2.52}"
CHART_APP_VERSION="${CHART_APP_VERSION:-latest}"
CHARTMUSEUM_URL="${CHARTMUSEUM_URL:-http://192.168.1.106:8081}"

IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST:-harbor.lan}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-premyom}"
IMAGE_NAME="${IMAGE_NAME:-onyxia-code-server}"
CODE_SERVER_VERSION="${CODE_SERVER_VERSION:-4.106.3}"
MINIFORGE_VERSION="${MINIFORGE_VERSION:-latest}"

IMAGE_REF="${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${IMG_TAG}"
TARBALL="premyom-code-server-${CHART_VERSION}.tgz"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] missing command: $1" >&2
    exit 1
  }
}

for cmd in docker helm curl tar grep sed mktemp; do
  require_cmd "$cmd"
done

echo "[INFO] repo: ${REPO_DIR}"
echo "[INFO] image: ${IMAGE_REF}"
echo "[INFO] chart: premyom-code-server:${CHART_VERSION}"
echo "[INFO] chartmuseum: ${CHARTMUSEUM_URL}"

echo "[STEP] updating chart references"
sed -i.bak -E "s#(version: ).*onyxia-code-server:[^[:space:]]+#\\1${IMAGE_REF}#g" "${CHART_DIR}/values.yaml"
sed -i.bak -E "s#(\"default\": \").*onyxia-code-server:[^\"]+(\",)#\\1${IMAGE_REF}\\2#g" "${CHART_DIR}/values.schema.json"
sed -i.bak -E "s#^version: .*#version: ${CHART_VERSION}#g" "${CHART_DIR}/Chart.yaml"
rm -f "${CHART_DIR}/values.yaml.bak" "${CHART_DIR}/values.schema.json.bak" "${CHART_DIR}/Chart.yaml.bak"

grep -n "version: ${IMAGE_REF}" "${CHART_DIR}/values.yaml"
grep -n "\"default\": \"${IMAGE_REF}\"" "${CHART_DIR}/values.schema.json"
grep -n "^version: ${CHART_VERSION}$" "${CHART_DIR}/Chart.yaml"

echo "[STEP] building and pushing image"
(
  cd "${IMAGE_DIR}"
  IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST}" \
  IMAGE_NAMESPACE="${IMAGE_NAMESPACE}" \
  IMAGE_TAG="${IMG_TAG}" \
  CODE_SERVER_VERSION="${CODE_SERVER_VERSION}" \
  MINIFORGE_VERSION="${MINIFORGE_VERSION}" \
  ./build_and_push.sh
)

echo "[STEP] smoke-testing image"
docker run --rm --entrypoint /bin/bash "${IMAGE_REF}" -lc \
  'python3.12 --version && source /opt/conda/etc/profile.d/conda.sh && conda --version && nano --version | head -n1'

echo "[STEP] packaging chart"
(
  cd "${REPO_DIR}"
  helm package premyom-code-server --version "${CHART_VERSION}" --app-version "${CHART_APP_VERSION}"
)

echo "[STEP] validating packaged chart content"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
tar -xzf "${REPO_DIR}/${TARBALL}" -C "${TMP_DIR}"
grep -n "version: ${IMAGE_REF}" "${TMP_DIR}/premyom-code-server/values.yaml"
grep -n "\"default\": \"${IMAGE_REF}\"" "${TMP_DIR}/premyom-code-server/values.schema.json"
grep -n "^version: ${CHART_VERSION}$" "${TMP_DIR}/premyom-code-server/Chart.yaml"

echo "[STEP] pushing chart to ChartMuseum"
curl --fail-with-body --data-binary "@${REPO_DIR}/${TARBALL}" "${CHARTMUSEUM_URL%/}/api/charts"

echo "[STEP] verifying index.yaml"
curl -fsSL "${CHARTMUSEUM_URL%/}/index.yaml" | grep -n "premyom-code-server-${CHART_VERSION}.tgz"

cat <<EOF
[DONE] release published.
Next commands (arkam-master):
  k -n onyxia rollout restart deploy/onyxia-api
  k -n onyxia rollout status deploy/onyxia-api --timeout=180s
EOF
