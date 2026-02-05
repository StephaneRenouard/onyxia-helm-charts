FROM debian:bookworm-slim

ARG FILEBROWSER_VERSION=2.32.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    fuse3 \
    s3fs \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) fb_arch="linux-amd64" ;; \
    arm64) fb_arch="linux-arm64" ;; \
    *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
  esac; \
  url="https://github.com/filebrowser/filebrowser/releases/download/v${FILEBROWSER_VERSION}/filebrowser_${FILEBROWSER_VERSION}_${fb_arch}.tar.gz"; \
  curl -fsSL "$url" -o /tmp/filebrowser.tgz; \
  tar -xzf /tmp/filebrowser.tgz -C /usr/local/bin filebrowser; \
  rm -f /tmp/filebrowser.tgz; \
  chmod +x /usr/local/bin/filebrowser

COPY premyom-s3-explorer/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/opt/onyxia-init.sh"]
CMD ["/usr/local/bin/filebrowser", "--noauth", "--address", "0.0.0.0", "--port", "8080", "--root", "/mnt/s3", "--database", "/tmp/filebrowser.db", "--log", "stdout"]

