FROM debian:bookworm-slim

ARG MINIFORGE_VERSION=latest
ARG JUPYTERLAB_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    fuse3 \
    s3fs \
    git \
    nano \
    sudo \
    tini \
  && rm -rf /var/lib/apt/lists/*

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
  /opt/conda/bin/conda install -y "python=3.12" pip; \
  if [ "${JUPYTERLAB_VERSION}" = "latest" ]; then \
    /opt/conda/bin/pip install --no-cache-dir jupyterlab; \
  else \
    /opt/conda/bin/pip install --no-cache-dir "jupyterlab==${JUPYTERLAB_VERSION}"; \
  fi; \
  /opt/conda/bin/python --version; \
  /opt/conda/bin/conda --version; \
  /opt/conda/bin/jupyter lab --version; \
  /opt/conda/bin/conda clean -afy; \
  ln -sf /opt/conda/bin/python /usr/local/bin/python; \
  ln -sf /opt/conda/bin/python /usr/local/bin/python3; \
  ln -sf /opt/conda/bin/python /usr/local/bin/python3.12; \
  if [ -x /opt/conda/bin/conda ]; then \
    ln -sf /opt/conda/bin/conda /usr/local/bin/conda; \
  elif [ -x /opt/conda/condabin/conda ]; then \
    ln -sf /opt/conda/condabin/conda /usr/local/bin/conda; \
  fi; \
  ln -sf /opt/conda/bin/pip /usr/local/bin/pip; \
  ln -sf /opt/conda/bin/pip /usr/local/bin/pip3; \
  ln -sf /opt/conda/bin/jupyter /usr/local/bin/jupyter

ENV CONDA_DIR=/opt/conda
ENV PATH=/opt/conda/bin:/opt/conda/condabin:$PATH

RUN useradd -m -s /bin/bash -g users onyxia \
  && mkdir -p /home/onyxia/work \
  && chown -R onyxia:users /home/onyxia

COPY premyom-jupyter/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/opt/onyxia-init.sh"]
CMD ["/opt/conda/bin/jupyter", "lab", "--ServerApp.ip=0.0.0.0", "--ServerApp.port=8080", "--ServerApp.open_browser=False", "--ServerApp.token=", "--ServerApp.password=", "--ServerApp.allow_origin=*", "--ServerApp.allow_remote_access=True", "--ServerApp.trust_xheaders=True", "--ServerApp.root_dir=/home/onyxia/work", "--ServerApp.default_url=/lab"]
