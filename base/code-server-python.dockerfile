FROM debian:bookworm-slim

ARG CODE_SERVER_VERSION=4.106.3

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    openssh-client \
    procps \
    tini \
    python3 \
    python3-pip \
    python3-venv \
  && rm -rf /var/lib/apt/lists/*

RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL -o /tmp/code-server.deb \
      "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_${ARCH}.deb" \
  && apt-get update \
  && apt-get install -y --no-install-recommends /tmp/code-server.deb \
  && rm -f /tmp/code-server.deb \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -g users onyxia \
  && mkdir -p /home/onyxia/work \
  && chown -R onyxia:users /home/onyxia

RUN mkdir -p /opt \
  && cat > /opt/onyxia-init.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

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

exec "$@"
EOF
RUN chmod +x /opt/onyxia-init.sh

COPY base/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER onyxia
WORKDIR /home/onyxia/work

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]

