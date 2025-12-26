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
  && printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '' \
    '# Compat minimale avec les charts IDE Onyxia:' \
    '# ils appellent /opt/onyxia-init.sh <cmd...> ; ici on passe juste le relai.' \
    'exec "$@"' \
    > /opt/onyxia-init.sh \
  && chmod +x /opt/onyxia-init.sh

COPY base/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER onyxia
WORKDIR /home/onyxia/work

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
