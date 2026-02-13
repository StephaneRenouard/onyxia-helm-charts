#!/usr/bin/env bash
set -euo pipefail

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
  local mode="${6:-rw}"

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
    -o "uid=$(id -u onyxia 2>/dev/null || echo 1000)"
    -o "gid=$(id -g onyxia 2>/dev/null || echo 100)"
    -o "umask=0002"
    -o "mp_umask=0002"
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
    map(select(test("^(hds-|nonhds-)?[a-z0-9.-]+(_(ro|rw))?$"))) |
    map(
      (sub("_(ro|rw)$";"")) as $raw |
      {
        scope: (if ($raw | startswith("hds-")) then "hds" else "nonhds" end),
        bucket: $raw,
        name: (
          if ($raw | startswith("hds-")) then ($raw | sub("^hds-";""))
          elif ($raw | startswith("nonhds-")) then ($raw | sub("^nonhds-";""))
          else $raw
          end
        ),
        mode: (if test("_(ro|rw)$") then capture("_(?<m>ro|rw)$").m else "rw" end)
      }
    ) |
    reduce .[] as $g (
      {};
      ($g.scope + "/" + $g.name) as $k |
      .[$k] = {
        bucket: (
          if $g.scope == "nonhds" then
            if ((.[$k].bucket // "") | startswith("nonhds-")) then .[$k].bucket
            elif ($g.bucket | startswith("nonhds-")) then $g.bucket
            else $g.bucket
            end
          else $g.bucket
          end
        ),
        mode: (if ((.[$k].mode // "ro") == "rw") or ($g.mode == "rw") then "rw" else "ro" end)
      }
    )
  ')"

  mapfile -t _mount_lines < <(echo "${mounts_json}" | jq -r 'to_entries[] | "\(.key)\t\(.value.bucket)\t\(.value.mode)"')

  declare -A _dotted_orgs=()
  for _line in "${_mount_lines[@]}"; do
    IFS=$'\t' read -r _key _bucket _mode <<< "${_line}"
    _name="${_key#*/}"
    if [[ "${_name}" == *.* ]]; then
      _org="${_name%%.*}"
      _dotted_orgs["${_org}"]=1
    fi
  done

  for _line in "${_mount_lines[@]}"; do
    IFS=$'\t' read -r key bucket mode <<< "${_line}"
    scope="${key%%/*}"
    name="${key#*/}"

    if [[ "${name}" != *.* ]] && [[ -n "${_dotted_orgs[${name}]:-}" ]]; then
      mount_suffix="${name}/_bucket"
    else
      mount_suffix="${name//./\/}"
    fi

    if [ "${scope}" = "hds" ]; then
      s3fs_mount_bucket "${bucket}" "${root}/hds/${mount_suffix}" "${hds_url}" "${hds_access_key}" "${hds_secret_key}" "${mode}"
    else
      s3fs_mount_bucket "${bucket}" "${root}/nonhds/${mount_suffix}" "${nonhds_url}" "${nonhds_access_key}" "${nonhds_secret_key}" "${mode}"
    fi
  done
}

configure_jupyter_defaults() {
  local workdir="/home/onyxia/work"
  local theme="${JUPYTER_DARK_THEME:-JupyterLab Dark}"

  mkdir -p "${workdir}"
  mkdir -p "/home/onyxia/.jupyter/lab/user-settings/@jupyterlab/apputils-extension"

  cat > /home/onyxia/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings <<JSON
{
  "theme": "${theme}"
}
JSON

  if [ -d "/mnt/s3" ]; then
    ln -sfn "/mnt/s3" "${workdir}/s3" || true
    [ -d "/mnt/s3/nonhds" ] && ln -sfn "/mnt/s3/nonhds" "${workdir}/s3-nonhds" || true
    [ -d "/mnt/s3/hds" ] && ln -sfn "/mnt/s3/hds" "${workdir}/s3-hds" || true
  fi

  chown -R onyxia:users /home/onyxia
}

normalize_jupyter_args() {
  JUPYTER_CMD=("$@")
  if [ "$#" -lt 1 ]; then
    return 0
  fi
  if [ "${1##*/}" != "jupyter" ]; then
    return 0
  fi

  local default_url="${JUPYTER_DEFAULT_URL:-/lab}"
  local args=("$@")
  local out=()
  local has_root_dir="false"

  for arg in "${args[@]}"; do
    case "${arg}" in
      --ServerApp.default_url=*)
        continue
        ;;
      --ServerApp.root_dir=*)
        has_root_dir="true"
        out+=("${arg}")
        ;;
      *)
        out+=("${arg}")
        ;;
    esac
  done

  out+=("--ServerApp.default_url=${default_url}")
  if [ "${has_root_dir}" != "true" ]; then
    out+=("--ServerApp.root_dir=/home/onyxia/work")
  fi

  JUPYTER_CMD=("${out[@]}")
}

JUPYTER_CMD=("$@")
normalize_jupyter_args "${JUPYTER_CMD[@]}" || true
premyom_mount_s3 || true
configure_jupyter_defaults || true

if [ "$(id -u)" -eq 0 ]; then
  exec sudo -EHu onyxia -- "${JUPYTER_CMD[@]}"
fi

exec "${JUPYTER_CMD[@]}"
