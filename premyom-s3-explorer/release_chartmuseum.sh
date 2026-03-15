#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${REPO_DIR}/premyom-s3-explorer"
IMAGE_DIR="${CHART_DIR}/image"

IMG_TAG="${IMG_TAG:-0.1.7}"
CHART_VERSION="${CHART_VERSION:-0.1.50}"
CHART_APP_VERSION="${CHART_APP_VERSION:-latest}"
CHARTMUSEUM_URL="${CHARTMUSEUM_URL:-http://192.168.1.106:8081}"

IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST:-harbor.lan}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-premyom}"
IMAGE_NAME="${IMAGE_NAME:-onyxia-s3-explorer}"
FILEBROWSER_VERSION="${FILEBROWSER_VERSION:-2.57.1}"
DOCKER_NO_CACHE="${DOCKER_NO_CACHE:-true}"
DOCKER_PULL="${DOCKER_PULL:-true}"

IMAGE_REF="${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${IMG_TAG}"
TARBALL="premyom-s3-explorer-${CHART_VERSION}.tgz"
ALLOW_DIRTY_RELEASE="${ALLOW_DIRTY_RELEASE:-0}"
SKIP_GIT_SYNC_CHECK="${SKIP_GIT_SYNC_CHECK:-0}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] missing command: $1" >&2
    exit 1
  }
}

require_bool() {
  local var_name="$1"
  local value="${!var_name:-}"
  case "$value" in
    true|false) ;;
    *)
      echo "[ERROR] ${var_name} must be 'true' or 'false' (got: ${value})" >&2
      exit 1
      ;;
  esac
}

select_hash_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    HASH_CMD=(sha256sum)
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    HASH_CMD=(shasum -a 256)
    return
  fi
  echo "[ERROR] missing command: sha256sum/shasum" >&2
  exit 1
}

compute_dir_sha() {
  local dir="$1"
  local tmp_file
  tmp_file="$(mktemp)"
  (
    cd "$dir"
    find . -type f -print0 \
      | LC_ALL=C sort -z \
      | while IFS= read -r -d '' path; do
          printf '%s  %s\n' "$("${HASH_CMD[@]}" "$path" | awk '{print $1}')" "${path#./}"
        done
  ) > "${tmp_file}"
  "${HASH_CMD[@]}" "${tmp_file}" | awk '{print $1}'
  rm -f "${tmp_file}"
}

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR}" ]; then
    rm -rf "${TMP_DIR}"
  fi
  if [ "${RESTORE_CHART_FILES:-0}" = "1" ]; then
    git -C "${REPO_DIR}" checkout -- \
      "premyom-s3-explorer/values.yaml" \
      "premyom-s3-explorer/values.schema.json" \
      "premyom-s3-explorer/Chart.yaml" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

for cmd in docker helm curl tar grep sed mktemp git awk find sort; do
  require_cmd "$cmd"
done
select_hash_cmd
require_bool DOCKER_NO_CACHE
require_bool DOCKER_PULL

if ! docker info >/dev/null 2>&1; then
  echo "[ERROR] docker daemon unavailable (check docker service / permissions)." >&2
  exit 1
fi

DOCKER_FLAGS=()
if [ "${DOCKER_NO_CACHE}" = "true" ]; then
  DOCKER_FLAGS+=(--no-cache)
fi
if [ "${DOCKER_PULL}" = "true" ]; then
  DOCKER_FLAGS+=(--pull)
fi
if [ "${#DOCKER_FLAGS[@]}" -eq 0 ]; then
  echo "[INFO] docker build flags: (none)"
else
  echo "[INFO] docker build flags: ${DOCKER_FLAGS[*]}"
fi


GIT_COMMIT="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
GIT_DIRTY_COUNT="$(git -C "${REPO_DIR}" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')"
GIT_BRANCH="$(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
ORIGIN_MAIN_SHA="$(git -C "${REPO_DIR}" rev-parse --short origin/main 2>/dev/null || echo unknown)"
IMAGE_SOURCE_SHA="$(compute_dir_sha "${IMAGE_DIR}")"

echo "[INFO] repo: ${REPO_DIR}"
echo "[INFO] git branch: ${GIT_BRANCH}"
echo "[INFO] git commit: ${GIT_COMMIT}"
echo "[INFO] origin/main: ${ORIGIN_MAIN_SHA}"
echo "[INFO] git dirty files: ${GIT_DIRTY_COUNT}"
echo "[INFO] image: ${IMAGE_REF}"
echo "[INFO] chart: premyom-s3-explorer:${CHART_VERSION}"
echo "[INFO] chartmuseum: ${CHARTMUSEUM_URL}"
echo "[INFO] image source sha: ${IMAGE_SOURCE_SHA}"

if [ "${ALLOW_DIRTY_RELEASE}" != "1" ] && [ "${GIT_DIRTY_COUNT}" != "0" ]; then
  echo "[ERROR] Refusing release from dirty repo (git dirty files: ${GIT_DIRTY_COUNT})." >&2
  echo "        Commit/stash changes or rerun with ALLOW_DIRTY_RELEASE=1 (not recommended)." >&2
  exit 1
fi

if [ "${SKIP_GIT_SYNC_CHECK}" != "1" ]; then
  echo "[STEP] checking git sync with origin/main"
  git -C "${REPO_DIR}" fetch origin main --quiet || true
  local_main_sha="$(git -C "${REPO_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  remote_main_sha="$(git -C "${REPO_DIR}" rev-parse --short origin/main 2>/dev/null || echo unknown)"
  echo "[INFO] local HEAD: ${local_main_sha}"
  echo "[INFO] remote HEAD: ${remote_main_sha}"
  if [ "${local_main_sha}" != "${remote_main_sha}" ]; then
    echo "[ERROR] Local repo is not at origin/main HEAD. Refusing release." >&2
    echo "        Run: git stash (if needed) && git pull --ff-only" >&2
    exit 1
  fi
fi

echo "[STEP] updating chart references"
RESTORE_CHART_FILES=1
sed -i.bak -E "s#(repository: ).*#\\1${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}#g" "${CHART_DIR}/values.yaml"
sed -i.bak -E "s#(tag: ).*#\\1${IMG_TAG}#g" "${CHART_DIR}/values.yaml"
sed -i.bak -E "s#(\"repository\"[[:space:]]*:[[:space:]]*\\{[^}]*\"default\"[[:space:]]*:[[:space:]]*\")[^\"]+(\")#\\1${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}\\2#" "${CHART_DIR}/values.schema.json"
sed -i.bak -E 's#("tag"[[:space:]]*:[[:space:]]*\{[^}]*"default"[[:space:]]*:[[:space:]]*")[^"]+(")#\1'"${IMG_TAG}"'\2#' "${CHART_DIR}/values.schema.json"
sed -i.bak -E "s#^version: .*#version: ${CHART_VERSION}#g" "${CHART_DIR}/Chart.yaml"
rm -f "${CHART_DIR}/values.yaml.bak" "${CHART_DIR}/values.schema.json.bak" "${CHART_DIR}/Chart.yaml.bak"

grep -n "repository: ${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}" "${CHART_DIR}/values.yaml"
grep -n "tag: ${IMG_TAG}" "${CHART_DIR}/values.yaml"
grep -n "\"default\": \"${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}\"" "${CHART_DIR}/values.schema.json"
grep -n "\"default\": \"${IMG_TAG}\"" "${CHART_DIR}/values.schema.json"
grep -n "^version: ${CHART_VERSION}$" "${CHART_DIR}/Chart.yaml"

echo "[STEP] validating source content guardrails"
grep -n "redirectUrl" "${CHART_DIR}/templates/_helpers.tpl" "${CHART_DIR}/templates/oauth2-proxy-deployment.yaml"
grep -n "cookieDomain" "${CHART_DIR}/templates/_helpers.tpl" "${CHART_DIR}/templates/oauth2-proxy-deployment.yaml" "${CHART_DIR}/values.yaml" "${CHART_DIR}/values.schema.json"
grep -n "whitelistDomain" "${CHART_DIR}/templates/_helpers.tpl" "${CHART_DIR}/templates/oauth2-proxy-deployment.yaml" "${CHART_DIR}/values.yaml" "${CHART_DIR}/values.schema.json"
grep -n "callbackMode" "${CHART_DIR}/values.yaml" "${CHART_DIR}/values.schema.json"
grep -n "/oauth2/callback" "${CHART_DIR}/templates/_helpers.tpl"
grep -n "oauth2ProxyPrefix" "${CHART_DIR}/templates/_helpers.tpl" "${CHART_DIR}/templates/oauth2-proxy-deployment.yaml"
grep -n "callbackMode" "${CHART_DIR}/templates/oauth2-proxy-callback-ingressroute.yaml"
grep -n "apps.{{k8s.domain}}" "${CHART_DIR}/values.schema.json"
grep -n "X-Auth-Request-Redirect" "${CHART_DIR}/templates/oauth2-proxy-redirect-middleware.yaml"
grep -n "setup_filebrowser_policies" "${CHART_DIR}/image/onyxia-init.sh"
grep -n -- "--perm.download=false" "${CHART_DIR}/image/onyxia-init.sh"

echo "[STEP] building and pushing image"
(
  cd "${IMAGE_DIR}"
  IMAGE_REGISTRY_HOST="${IMAGE_REGISTRY_HOST}" \
  IMAGE_NAMESPACE="${IMAGE_NAMESPACE}" \
  IMAGE_TAG="${IMG_TAG}" \
  FILEBROWSER_VERSION="${FILEBROWSER_VERSION}" \
  DOCKER_NO_CACHE="${DOCKER_NO_CACHE}" \
  DOCKER_PULL="${DOCKER_PULL}" \
  BUILD_GIT_COMMIT="${GIT_COMMIT}" \
  BUILD_IMAGE_SOURCE_SHA="${IMAGE_SOURCE_SHA}" \
  ./build_and_push.sh
)

echo "[STEP] smoke-testing image"
docker run --rm --entrypoint /bin/bash "${IMAGE_REF}" -lc \
  'command -v filebrowser >/dev/null && filebrowser version >/dev/null 2>&1 || true && test -x /opt/onyxia-init.sh'

echo "[STEP] validating image provenance"
built_commit="$(docker image inspect "${IMAGE_REF}" --format '{{ index .Config.Labels "io.premyom.git-commit" }}')"
built_source_sha="$(docker image inspect "${IMAGE_REF}" --format '{{ index .Config.Labels "io.premyom.image-source-sha" }}')"
echo "[INFO] built label git-commit: ${built_commit}"
echo "[INFO] built label image-source-sha: ${built_source_sha}"
if [[ "${built_commit}" != "${GIT_COMMIT}" ]]; then
  echo "[ERROR] built image git commit label mismatch: expected ${GIT_COMMIT}, got ${built_commit}" >&2
  exit 1
fi
if [[ "${built_source_sha}" != "${IMAGE_SOURCE_SHA}" ]]; then
  echo "[ERROR] built image source sha label mismatch: expected ${IMAGE_SOURCE_SHA}, got ${built_source_sha}" >&2
  exit 1
fi

echo "[STEP] packaging chart"
(
  TMP_DIR="$(mktemp -d)"
  cp -a "${CHART_DIR}" "${TMP_DIR}/premyom-s3-explorer"
  cd "${TMP_DIR}"
  helm package premyom-s3-explorer --version "${CHART_VERSION}" --app-version "${CHART_APP_VERSION}"
  mv "${TMP_DIR}/${TARBALL}" "${REPO_DIR}/${TARBALL}"
)

echo "[STEP] validating packaged chart content"
TMP_DIR="$(mktemp -d)"
tar -xzf "${REPO_DIR}/${TARBALL}" -C "${TMP_DIR}"
grep -n "repository: ${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}" "${TMP_DIR}/premyom-s3-explorer/values.yaml"
grep -n "tag: ${IMG_TAG}" "${TMP_DIR}/premyom-s3-explorer/values.yaml"
grep -n "\"default\": \"${IMAGE_REGISTRY_HOST}/${IMAGE_NAMESPACE}/${IMAGE_NAME}\"" "${TMP_DIR}/premyom-s3-explorer/values.schema.json"
grep -n "\"default\": \"${IMG_TAG}\"" "${TMP_DIR}/premyom-s3-explorer/values.schema.json"
grep -n "^version: ${CHART_VERSION}$" "${TMP_DIR}/premyom-s3-explorer/Chart.yaml"
grep -n "redirectUrl" "${TMP_DIR}/premyom-s3-explorer/templates/_helpers.tpl" "${TMP_DIR}/premyom-s3-explorer/templates/oauth2-proxy-deployment.yaml"
grep -n "cookieDomain" "${TMP_DIR}/premyom-s3-explorer/templates/_helpers.tpl" "${TMP_DIR}/premyom-s3-explorer/templates/oauth2-proxy-deployment.yaml" "${TMP_DIR}/premyom-s3-explorer/values.yaml" "${TMP_DIR}/premyom-s3-explorer/values.schema.json"
grep -n "whitelistDomain" "${TMP_DIR}/premyom-s3-explorer/templates/_helpers.tpl" "${TMP_DIR}/premyom-s3-explorer/templates/oauth2-proxy-deployment.yaml" "${TMP_DIR}/premyom-s3-explorer/values.yaml" "${TMP_DIR}/premyom-s3-explorer/values.schema.json"
grep -n "callbackMode" "${TMP_DIR}/premyom-s3-explorer/values.yaml" "${TMP_DIR}/premyom-s3-explorer/values.schema.json"
grep -n "/oauth2/callback" "${TMP_DIR}/premyom-s3-explorer/templates/_helpers.tpl"
grep -n "oauth2ProxyPrefix" "${TMP_DIR}/premyom-s3-explorer/templates/_helpers.tpl" "${TMP_DIR}/premyom-s3-explorer/templates/oauth2-proxy-deployment.yaml"
grep -n "callbackMode" "${TMP_DIR}/premyom-s3-explorer/templates/oauth2-proxy-callback-ingressroute.yaml"
grep -n "apps.{{k8s.domain}}" "${TMP_DIR}/premyom-s3-explorer/values.schema.json"
grep -n "X-Auth-Request-Redirect" "${TMP_DIR}/premyom-s3-explorer/templates/oauth2-proxy-redirect-middleware.yaml"
grep -n "setup_filebrowser_policies" "${TMP_DIR}/premyom-s3-explorer/image/onyxia-init.sh"
grep -n -- "--perm.download=false" "${TMP_DIR}/premyom-s3-explorer/image/onyxia-init.sh"

echo "[STEP] pushing chart to ChartMuseum"
curl --fail-with-body --data-binary "@${REPO_DIR}/${TARBALL}" "${CHARTMUSEUM_URL%/}/api/charts"

echo "[STEP] verifying index.yaml"
curl -fsSL "${CHARTMUSEUM_URL%/}/index.yaml" | grep -n "premyom-s3-explorer-${CHART_VERSION}.tgz"

cat <<EOF
[DONE] release published.
Next commands (arkam-master):
  k -n onyxia rollout restart deploy/onyxia-api
  k -n onyxia rollout status deploy/onyxia-api --timeout=180s
EOF
