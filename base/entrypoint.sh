#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${WORKDIR:-/home/onyxia/work}"
PASSWORD="${PASSWORD:-changeme}"

mkdir -p "${WORKDIR}" "/home/onyxia/.config/code-server"

cat > /home/onyxia/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${PASSWORD}
cert: false
EOF

exec /usr/bin/code-server "${WORKDIR}" "$@"

