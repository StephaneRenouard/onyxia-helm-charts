#!/usr/bin/env bash
set -euo pipefail

# Copie du script commun (montages S3 + Vault k8s auth).
# À maintenir en cohérence avec `premyom-code-server/image/onyxia-init.sh`.

json_get() { jq -r "$1 // empty" 2>/dev/null || true; }

vault_login_kubernetes() {
  [ -n "${VAULT_TOKEN:-}" ] && return 0
  [ -n "${VAULT_ADDR:-}" ] || return 1
  jwt_file="/var/run/secrets/kubernetes.io/serviceaccount/token"
  [ -r "${jwt_file}" ] || return 1
  role="${VAULT_K8S_ROLE:-premyom-s3-read}"
  login_url="${VAULT_ADDR%/}/v1/auth/kubernetes/login"
  jwt="$(cat "${jwt_file}")"
  [ -n "${jwt}" ] || return 1
  body="$(jq -cn --arg role "${role}" --arg jwt "${jwt}" '{role:$role,jwt:$jwt}')"
  resp="$(curl -fsSL -X POST -H 'Content-Type: application/json' --data "${body}" "${login_url}" 2>/dev/null || true)"
  [ -n "${resp}" ] || return 1
  token="$(printf '%s' "${resp}" | json_get '.auth.client_token')"
  [ -n "${token}" ] || return 1
  export VAULT_TOKEN="${token}"
}

vault_read_kv() {
  path="$1"; key="$2"
  [ -n "${VAULT_ADDR:-}" ] || return 1
  [ -n "${VAULT_TOKEN:-}" ] || vault_login_kubernetes >/dev/null 2>&1 || true
  [ -n "${VAULT_TOKEN:-}" ] || return 1
  url="${VAULT_ADDR%/}/v1/${path#/}"
  payload="$(curl -fsSL -H "X-Vault-Token: ${VAULT_TOKEN}" "${url}" 2>/dev/null || true)"
  [ -n "${payload}" ] || return 1
  printf '%s' "${payload}" | json_get ".data.data[\"${key}\"]" | grep -q . && { printf '%s' "${payload}" | json_get ".data.data[\"${key}\"]"; return 0; }
  printf '%s' "${payload}" | json_get ".data[\"${key}\"]"
}

s3fs_mount_bucket() {
  bucket="$1"; mount_point="$2"; endpoint_url="$3"; access_key="$4"; secret_key="$5"; mode="${6:-rw}"
  mkdir -p "${mount_point}"
  passwd_file="/tmp/passwd-s3fs-${bucket}"
  printf '%s:%s' "${access_key}" "${secret_key}" > "${passwd_file}"
  chmod 600 "${passwd_file}"
  opts=(-o "passwd_file=${passwd_file}" -o "url=${endpoint_url}" -o "use_path_request_style" -o "nonempty" -o "allow_other" -o "mp_umask=0022")
  [ "${mode}" = "ro" ] && opts+=(-o "ro")
  echo "[INFO] s3fs mount: ${bucket} -> ${mount_point} (${mode})"
  s3fs "${bucket}" "${mount_point}" "${opts[@]}"
}

premyom_mount_s3() {
  [ "${PREMYOM_S3_MOUNT_ENABLED:-false}" = "true" ] || return 0
  nonhds_host="${PREMYOM_S3_NONHDS_ENDPOINT_HOST:-}"
  hds_host="${PREMYOM_S3_HDS_ENDPOINT_HOST:-}"
  nonhds_path="${PREMYOM_S3_VAULT_NONHDS_PATH:-}"
  hds_path="${PREMYOM_S3_VAULT_HDS_PATH:-}"
  root="${PREMYOM_S3_MOUNT_ROOT:-/mnt/s3}"
  if [ -z "${nonhds_host}" ] || [ -z "${hds_host}" ] || [ -z "${nonhds_path}" ] || [ -z "${hds_path}" ]; then
    echo "[WARN] PREMYOM_S3_MOUNT_ENABLED=true but missing endpoint/path vars; skipping mounts." >&2
    return 0
  fi
  nonhds_access_key="$(vault_read_kv "${nonhds_path}" "AWS_ACCESS_KEY_ID" || true)"
  nonhds_secret_key="$(vault_read_kv "${nonhds_path}" "AWS_SECRET_ACCESS_KEY" || true)"
  hds_access_key="$(vault_read_kv "${hds_path}" "AWS_ACCESS_KEY_ID" || true)"
  hds_secret_key="$(vault_read_kv "${hds_path}" "AWS_SECRET_ACCESS_KEY" || true)"
  if [ -z "${nonhds_access_key}" ] || [ -z "${nonhds_secret_key}" ] || [ -z "${hds_access_key}" ] || [ -z "${hds_secret_key}" ]; then
    echo "[WARN] Vault read failed for S3 credentials; skipping mounts." >&2
    return 0
  fi
  nonhds_url="https://${nonhds_host}"
  hds_url="https://${hds_host}"
  groups_json="${ONYXIA_USER_GROUPS:-[]}"
  if ! echo "${groups_json}" | jq -e . >/dev/null 2>&1; then
    groups_json="$(printf '%s' "${groups_json}" | tr ', ' '\n' | awk 'NF{print}' | jq -Rsc 'split(\"\\n\")[:-1]')"
  fi
  mounts_json="$(echo "${groups_json}" | jq -c '
    map(tostring) |
    map(select(test(\"^(hds-)?[a-z0-9.-]+_(ro|rw)$\"))) |
    map({scope:(if startswith(\"hds-\") then \"hds\" else \"nonhds\" end),name:(sub(\"^hds-\";\"\")|sub(\"_(ro|rw)$\";\"\")),mode:(capture(\"_(?<m>ro|rw)$\").m)}) |
    reduce .[] as $g ({}; .[(($g.scope)+\"/\"+($g.name))] = (if (.[(($g.scope)+\"/\"+($g.name))] // \"ro\") == \"rw\" or $g.mode == \"rw\" then \"rw\" else \"ro\" end))
  ')"
  echo "${mounts_json}" | jq -r 'to_entries[] | \"\\(.key)\\t\\(.value)\"' | while IFS=$'\t' read -r key mode; do
    scope="${key%%/*}"
    name="${key#*/}"
    mount_suffix="${name//./\/}"
    if [ "${scope}" = "hds" ]; then
      s3fs_mount_bucket "hds-${name}" "${root}/hds/${mount_suffix}" "${hds_url}" "${hds_access_key}" "${hds_secret_key}" "${mode}"
    else
      s3fs_mount_bucket "${name}" "${root}/nonhds/${mount_suffix}" "${nonhds_url}" "${nonhds_access_key}" "${nonhds_secret_key}" "${mode}"
    fi
  done
}

premyom_mount_s3 || true

exec "$@"

