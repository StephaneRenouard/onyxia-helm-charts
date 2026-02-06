#!/usr/bin/env bash
set -euo pipefail

# NOTE: ce script est copié dans plusieurs images (code-server, s3-explorer).
# Garder la logique commune ici si possible.

# --- Helpers ----------------------------------------------------------------

json_get() {
  local expr="$1"
  jq -r "$expr // empty" 2>/dev/null || true
}

vault_login_kubernetes() {
  if [ -n "${VAULT_TOKEN:-}" ]; then
    return 0
  fi
  if [ -z "${VAULT_ADDR:-}" ]; then
    return 1
  fi
  local jwt_file="/var/run/secrets/kubernetes.io/serviceaccount/token"
  if [ ! -r "${jwt_file}" ]; then
    return 1
  fi
  local role="${VAULT_K8S_ROLE:-premyom-s3-read}"
  local login_url="${VAULT_ADDR%/}/v1/auth/kubernetes/login"

  local jwt
  jwt="$(cat "${jwt_file}")"
  [ -n "${jwt}" ] || return 1

  local body
  body="$(jq -cn --arg role "${role}" --arg jwt "${jwt}" '{role:$role,jwt:$jwt}')"

  local resp
  resp="$(curl -fsSL -X POST -H 'Content-Type: application/json' --data "${body}" "${login_url}" 2>/dev/null || true)"
  [ -n "${resp}" ] || return 1

  local token
  token="$(printf '%s' "${resp}" | json_get '.auth.client_token')"
  [ -n "${token}" ] || return 1

  export VAULT_TOKEN="${token}"
  return 0
}

vault_read_kv() {
  local path="$1"
  local key="$2"
  if [ -z "${VAULT_ADDR:-}" ]; then
    return 1
  fi
  if [ -z "${VAULT_TOKEN:-}" ]; then
    vault_login_kubernetes >/dev/null 2>&1 || true
  fi
  if [ -z "${VAULT_TOKEN:-}" ]; then
    return 1
  fi
  local url="${VAULT_ADDR%/}/v1/${path#/}"
  local payload
  payload="$(curl -fsSL -H "X-Vault-Token: ${VAULT_TOKEN}" "${url}" 2>/dev/null || true)"
  if [ -z "${payload}" ]; then
    return 1
  fi
  # KV v2: .data.data.KEY ; KV v1: .data.KEY
  printf '%s' "${payload}" | json_get ".data.data[\"${key}\"]" | grep -q . && {
    printf '%s' "${payload}" | json_get ".data.data[\"${key}\"]"
    return 0
  }
  printf '%s' "${payload}" | json_get ".data[\"${key}\"]"
}

s3fs_mount_bucket() {
  local bucket="$1"
  local mount_point="$2"
  local endpoint_url="$3"
  local access_key="$4"
  local secret_key="$5"
  local mode="${6:-rw}" # rw|ro

  mkdir -p "${mount_point}"

  local passwd_file="/tmp/passwd-s3fs-${bucket}"
  printf '%s:%s' "${access_key}" "${secret_key}" > "${passwd_file}"
  chmod 600 "${passwd_file}"

  local opts=(
    -o "passwd_file=${passwd_file}"
    -o "url=${endpoint_url}"
    -o "use_path_request_style"
    -o "nonempty"
    -o "allow_other"
    -o "mp_umask=0022"
  )
  if [ "${mode}" = "ro" ]; then
    opts+=(-o "ro")
  fi

  echo "[INFO] s3fs mount: ${bucket} -> ${mount_point} (${mode})"
  s3fs "${bucket}" "${mount_point}" "${opts[@]}"
}

premyom_mount_s3() {
  if [ "${PREMYOM_S3_MOUNT_ENABLED:-false}" != "true" ]; then
    return 0
  fi

  local nonhds_host="${PREMYOM_S3_NONHDS_ENDPOINT_HOST:-}"
  local hds_host="${PREMYOM_S3_HDS_ENDPOINT_HOST:-}"
  local nonhds_path="${PREMYOM_S3_VAULT_NONHDS_PATH:-}"
  local hds_path="${PREMYOM_S3_VAULT_HDS_PATH:-}"
  local root="${PREMYOM_S3_MOUNT_ROOT:-/mnt/s3}"

  if [ -z "${nonhds_host}" ] || [ -z "${hds_host}" ] || [ -z "${nonhds_path}" ] || [ -z "${hds_path}" ]; then
    echo "[WARN] PREMYOM_S3_MOUNT_ENABLED=true but missing endpoint/path vars; skipping mounts." >&2
    return 0
  fi

  local nonhds_access_key nonhds_secret_key hds_access_key hds_secret_key
  nonhds_access_key="$(vault_read_kv "${nonhds_path}" "AWS_ACCESS_KEY_ID" || true)"
  nonhds_secret_key="$(vault_read_kv "${nonhds_path}" "AWS_SECRET_ACCESS_KEY" || true)"
  hds_access_key="$(vault_read_kv "${hds_path}" "AWS_ACCESS_KEY_ID" || true)"
  hds_secret_key="$(vault_read_kv "${hds_path}" "AWS_SECRET_ACCESS_KEY" || true)"

  if [ -z "${nonhds_access_key}" ] || [ -z "${nonhds_secret_key}" ] || [ -z "${hds_access_key}" ] || [ -z "${hds_secret_key}" ]; then
    echo "[WARN] Vault read failed for S3 credentials; skipping mounts." >&2
    return 0
  fi

  local nonhds_url="https://${nonhds_host}"
  local hds_url="https://${hds_host}"

  local groups_json="${ONYXIA_USER_GROUPS:-[]}"
  if ! echo "${groups_json}" | jq -e . >/dev/null 2>&1; then
    groups_json="$(printf '%s' "${groups_json}" | tr ', ' '\n' | awk 'NF{print}' | jq -Rsc 'split("\n")[:-1]')"
  fi

  local mounts_json
  mounts_json="$(echo "${groups_json}" | jq -c '
    map(tostring | ltrimstr("/") | ascii_downcase) |
    # Groupes supportés:
    # - <bucket>[_ro|_rw]
    # - hds-<bucket>[_ro|_rw]
    # Le suffixe _ro/_rw est optionnel pour rester compatible avec des groupes existants.
    map(select(test("^(hds-)?[a-z0-9.-]+(_(ro|rw))?$"))) |
    map({
      scope: (if startswith("hds-") then "hds" else "nonhds" end),
      name: (sub("^hds-";"") | sub("_(ro|rw)$";"")),
      # Par défaut, si pas de suffixe, on considère RW (un groupe implique un accès effectif).
      mode: (if test("_(ro|rw)$") then capture("_(?<m>ro|rw)$").m else "rw" end)
    }) |
    reduce .[] as $g ({}; .[(($g.scope)+"/"+($g.name))] =
      (if (.[(($g.scope)+"/"+($g.name))] // "ro") == "rw" or $g.mode == "rw" then "rw" else "ro" end)
    )
  ')"

  echo "${mounts_json}" | jq -r 'to_entries[] | "\(.key)\t\(.value)"' | while IFS=$'\t' read -r key mode; do
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

normalize_codeserver_args() {
  if [ "$#" -lt 2 ]; then
    return 0
  fi
  if [ "${1}" != "/usr/bin/code-server" ] && [ "${1##*/}" != "code-server" ]; then
    return 0
  fi

  local args=("$@")
  local out=()
  local host=""

  for i in "${!args[@]}"; do
    if [ "${args[$i]}" = "--host" ] && [ $((i+1)) -lt ${#args[@]} ]; then
      host="${args[$((i+1))]}"
      continue
    fi
    if [ $i -gt 0 ] && [ "${args[$((i-1))]}" = "--host" ]; then
      continue
    fi
    out+=("${args[$i]}")
  done

  if [ -n "${host}" ]; then
    local final=()
    final+=("${out[0]}")
    final+=("--bind-addr" "${host}:8080")
    for j in "${!out[@]}"; do
      [ "$j" -eq 0 ] && continue
      final+=("${out[$j]}")
    done
    set -- "${final[@]}"
  fi
}

# --- Compat minimale avec les charts IDE Onyxia ------------------------------

if [ "${CODE_SERVER_AUTH:-password}" = "none" ]; then
  if [ "$#" -ge 1 ] && [[ "${1}" == *"code-server" ]]; then
    if ! printf '%s\n' "$@" | grep -qE '^--auth$|^--auth='; then
      args=("$@")
      last_index=$(( ${#args[@]} - 1 ))
      new_args=()
      for i in "${!args[@]}"; do
        if [ "$i" -eq "$last_index" ]; then
          new_args+=("--auth" "none")
        fi
        new_args+=("${args[$i]}")
      done
      set -- "${new_args[@]}"
    fi
  fi
fi

normalize_codeserver_args "$@" || true

premyom_mount_s3 || true

exec "$@"
