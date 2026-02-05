#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${WORKDIR:-/home/onyxia/work}"
PASSWORD="${PASSWORD:-changeme}"
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-password}"

mkdir -p "${WORKDIR}" "/home/onyxia/.config/code-server"

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

