FROM debian:bookworm-slim

ARG CODE_SERVER_VERSION=4.106.3
ARG MINIFORGE_VERSION=latest

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
    nano \
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

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) mf_arch="x86_64" ;; \
    arm64) mf_arch="aarch64" ;; \
    *) echo "Unsupported arch for Miniforge: $arch" >&2; exit 1 ;; \
  esac; \
  if [ "${MINIFORGE_VERSION}" = "latest" ]; then \
    installer_url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${mf_arch}.sh"; \
  else \
    installer_url="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${mf_arch}.sh"; \
  fi; \
  curl -fsSL "$installer_url" -o /tmp/miniforge.sh; \
  bash /tmp/miniforge.sh -b -p /opt/conda; \
  rm -f /tmp/miniforge.sh; \
  /opt/conda/bin/conda install -y "python=3.12"; \
  /opt/conda/bin/python --version; \
  /opt/conda/bin/conda --version; \
  /opt/conda/bin/conda clean -afy; \
  ln -sf /opt/conda/bin/python /usr/local/bin/python; \
  ln -sf /opt/conda/bin/python /usr/local/bin/python3; \
  ln -sf /opt/conda/bin/python /usr/local/bin/python3.12; \
  ln -sf /opt/conda/bin/pip /usr/local/bin/pip; \
  ln -sf /opt/conda/bin/pip /usr/local/bin/pip3

ENV CONDA_DIR=/opt/conda
ENV PATH=/opt/conda/bin:$PATH

RUN useradd -m -s /bin/bash -g users onyxia \
  && mkdir -p /home/onyxia/work \
  && chown -R onyxia:users /home/onyxia

COPY premyom-code-server/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

COPY premyom-code-server/image/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
