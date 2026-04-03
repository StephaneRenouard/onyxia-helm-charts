FROM debian:bookworm-slim

ARG SOFA_VERSION=25.12.00
ARG SOFA_DOWNLOAD_URL=""
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    fuse3 \
    s3fs \
    nano \
    sudo \
    tini \
    python3 \
    procps \
    xpra \
    libjs-jquery \
    python3-pil \
    python3-netifaces \
    dbus-x11 \
    xauth \
    unzip \
    wmctrl \
    xvfb \
    libglu1-mesa \
    libgl1 \
    libegl1 \
    libxrender1 \
    libxext6 \
    libxt6 \
    libsm6 \
    libnss3 \
    libasound2 \
    libpulse0 \
    libpulse-mainloop-glib0 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxrandr2 \
    libxdamage1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libx11-xcb1 \
    libxcb1 \
    libxcb-cursor0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-randr0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-render0 \
    libxcb-xkb1 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xinput0 \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) sofa_arch="amd64" ;; \
    *) echo "Unsupported arch for SOFA: $arch" >&2; exit 1 ;; \
  esac; \
  url="${SOFA_DOWNLOAD_URL}"; \
  if [ -z "${url}" ]; then \
    url="https://github.com/sofa-framework/sofa/releases/download/v${SOFA_VERSION}/SOFA_v${SOFA_VERSION}_Linux-Python_3.12.zip"; \
  fi; \
  curl -fL "${url}" -o /tmp/sofa.zip; \
  mkdir -p /opt; \
  unzip -q /tmp/sofa.zip -d /opt; \
  rm -f /tmp/sofa.zip; \
  sofa_dir="$(find /opt -maxdepth 1 -type d -name 'SOFA_v*_Linux' | head -n1)"; \
  [ -n "${sofa_dir}" ]; \
  [ -x "${sofa_dir}/bin/runSofa" ]; \
  ln -sfn "${sofa_dir}" /opt/sofa; \
  ln -sfn /opt/sofa/bin/runSofa /usr/local/bin/runSofa

RUN useradd -m -s /bin/bash -g users onyxia \
  && mkdir -p /home/onyxia/work /home/onyxia/.xpra \
  && chown -R onyxia:users /home/onyxia \
  && printf 'onyxia ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/onyxia \
  && chmod 0440 /etc/sudoers.d/onyxia

COPY premyom-sofa/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/opt/onyxia-init.sh"]
CMD []
