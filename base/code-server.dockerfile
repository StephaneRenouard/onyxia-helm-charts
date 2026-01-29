FROM debian:bookworm-slim

ARG CODE_SERVER_VERSION=4.106.3

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    procps \
    s3fs \
    fuse3 \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL -o /tmp/code-server.deb \
      "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_${ARCH}.deb" \
  && apt-get update \
  && apt-get install -y --no-install-recommends /tmp/code-server.deb \
  && rm -f /tmp/code-server.deb \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -g users onyxia \
  && usermod -aG fuse onyxia \
  && mkdir -p /home/onyxia/work \
  && chown -R onyxia:users /home/onyxia

RUN echo 'user_allow_other' >> /etc/fuse.conf

RUN mkdir -p /opt \
  && cat > /opt/onyxia-init.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# --- S3 mounts (Premyom) ----------------------------------------------------
# Goal: mount non-HDS and HDS buckets using s3fs, based on Keycloak groups
# passed by Onyxia at launch time.
#
# Required envs when enabled:
#   PREMYOM_S3_MOUNT_ENABLED=true
#   PREMYOM_S3_NONHDS_ENDPOINT_HOST=cellar-... (host only)
#   PREMYOM_S3_HDS_ENDPOINT_HOST=cellar-... (host only)
#   PREMYOM_S3_VAULT_NONHDS_PATH=secret/data/... (KV v2) or secret/... (KV v1)
#   PREMYOM_S3_VAULT_HDS_PATH=...
#   VAULT_ADDR / VAULT_TOKEN (injected by Onyxia if Vault is enabled)
#   ONYXIA_USER_GROUPS (JSON array or string)
#
# Expected Vault keys (KV):
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY

json_get() {
  local expr="$1"
  jq -r "$expr // empty" 2>/dev/null || true
}

vault_read_kv() {
  local path="$1"
  local key="$2"
  if [ -z "${VAULT_ADDR:-}" ] || [ -z "${VAULT_TOKEN:-}" ]; then
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

groups_has() {
  local needle="$1"
  local groups="${ONYXIA_USER_GROUPS:-}"
  # Accept JSON array or simple string.
  if echo "${groups}" | jq -e . >/dev/null 2>&1; then
    echo "${groups}" | jq -e --arg n "${needle}" '(.[]? | tostring) == $n' >/dev/null 2>&1
    return $?
  fi
  echo "${groups}" | grep -qE "(^|[^a-zA-Z0-9_-])${needle}([^a-zA-Z0-9_-]|$)"
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

  # Mapping rule (recommended):
  # - non-HDS groups: <bucket>_(ro|rw)  ex: imt_rw
  # - HDS groups:     hds-<bucket>_(ro|rw) ex: hds-imt_ro
  #
  # This function:
  # - derives bucket name from group name
  # - mounts under:
  #     /mnt/s3/nonhds/<bucket>
  #     /mnt/s3/hds/<bucket>
  # - uses ro/rw based on suffix, with rw overriding ro if both exist.

  local groups_json="${ONYXIA_USER_GROUPS:-[]}"
  if ! echo "${groups_json}" | jq -e . >/dev/null 2>&1; then
    # fallback: turn "a,b,c" or "a b c" into JSON array
    groups_json="$(printf '%s' "${groups_json}" | tr ', ' '\n' | awk 'NF{print}' | jq -Rsc 'split("\n")[:-1]')"
  fi

  # Build a map key -> mode, where key is "<scope>/<bucket>" and mode is ro|rw.
  # scope is "hds" or "nonhds".
  local mounts_json
  mounts_json="$(echo "${groups_json}" | jq -c '
    map(tostring) |
    map(select(test("^(hds-)?[a-z0-9-]+_(ro|rw)$"))) |
    map({
      scope: (if startswith("hds-") then "hds" else "nonhds" end),
      name: (sub("^hds-";"") | sub("_(ro|rw)$";"")),
      mode: (capture("_(?<m>ro|rw)$").m)
    }) |
    reduce .[] as $g ({}; .[(($g.scope)+\"/\"+($g.name))] =
      (if (.[(($g.scope)+\"/\"+($g.name))] // \"ro\") == \"rw\" or $g.mode == \"rw\" then \"rw\" else \"ro\" end)
    )
  ')"

  echo "${mounts_json}" | jq -r 'to_entries[] | "\(.key)\t\(.value)"' | while IFS=$'\t' read -r key mode; do
    scope="${key%%/*}"
    name="${key#*/}"
    if [ "${scope}" = "hds" ]; then
      s3fs_mount_bucket "hds-${name}" "${root}/hds/${name}" "${hds_url}" "${hds_access_key}" "${hds_secret_key}" "${mode}"
    else
      s3fs_mount_bucket "${name}" "${root}/nonhds/${name}" "${nonhds_url}" "${nonhds_access_key}" "${nonhds_secret_key}" "${mode}"
    fi
  done
}

# Compat minimale avec les charts IDE Onyxia:
# ils appellent /opt/onyxia-init.sh <cmd...>.
# Ici on injecte uniquement les options nécessaires à notre image.

if [ "${CODE_SERVER_AUTH:-password}" = "none" ]; then
  if [ "$#" -ge 1 ] && [[ "${1}" == *"code-server" ]]; then
    if ! printf '%s\n' "$@" | grep -qE '^--auth$|^--auth='; then
      # Le chart passe le workspace path en dernier argument.
      # On insère "--auth none" juste avant le dernier élément.
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

# Attempt S3 mounts before launching the main process.
premyom_mount_s3 || true

exec "$@"
EOF
RUN chmod +x /opt/onyxia-init.sh

COPY base/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER onyxia
WORKDIR /home/onyxia/work

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
