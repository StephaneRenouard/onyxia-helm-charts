FROM debian:bookworm-slim

ARG CODE_SERVER_VERSION=4.106.3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    fuse3 \
    s3fs \
    openssh-client \
    git \
    sudo \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  url="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION}_${arch}.deb"; \
  curl -fsSL "$url" -o /tmp/code-server.deb; \
  apt-get update; \
  apt-get install -y /tmp/code-server.deb; \
  rm -f /tmp/code-server.deb; \
  rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -g users onyxia \
  && mkdir -p /home/onyxia/work \
  && chown -R onyxia:users /home/onyxia

COPY premyom-code-server/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

COPY premyom-code-server/image/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]

