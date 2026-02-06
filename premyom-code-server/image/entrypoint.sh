#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${WORKDIR:-/home/onyxia/work}"
PASSWORD="${PASSWORD:-changeme}"
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-password}"

mkdir -p "${WORKDIR}" "/home/onyxia/.config/code-server"

# Make S3 mounts visible in the VS Code file explorer by default.
# VS Code shows only the opened folder (`WORKDIR`), so we expose the S3 mount tree
# via symlinks under the workdir.
if [ -d "/mnt/s3" ]; then
  ln -sfn "/mnt/s3" "${WORKDIR}/s3" || true
  [ -d "/mnt/s3/nonhds" ] && ln -sfn "/mnt/s3/nonhds" "${WORKDIR}/s3-nonhds" || true
  [ -d "/mnt/s3/hds" ] && ln -sfn "/mnt/s3/hds" "${WORKDIR}/s3-hds" || true
fi

if [ "${CODE_SERVER_AUTH}" = "none" ]; then
  cat > /home/onyxia/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOF
else
  cat > /home/onyxia/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${PASSWORD}
cert: false
EOF
fi

exec /usr/bin/code-server "${WORKDIR}" "$@"
