FROM debian:bookworm-slim

ARG SLICER_VERSION=5.8
ARG SLICER_DOWNLOAD_URL=""
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
    dbus-x11 \
    xauth \
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
    amd64) slicer_arch="amd64" ;; \
    *) echo "Unsupported arch for 3D Slicer: $arch" >&2; exit 1 ;; \
  esac; \
  url="${SLICER_DOWNLOAD_URL}"; \
  if [ -z "${url}" ]; then \
    url="https://download.slicer.org/download?os=linux&stability=release&version=${SLICER_VERSION}"; \
  fi; \
  curl -fL "${url}" -o /tmp/slicer.tar.gz; \
  mkdir -p /opt; \
  tar -xzf /tmp/slicer.tar.gz -C /opt; \
  rm -f /tmp/slicer.tar.gz; \
  slicer_dir="$(find /opt -maxdepth 1 -type d -name 'Slicer*' | head -n1)"; \
  [ -n "${slicer_dir}" ]; \
  [ -x "${slicer_dir}/Slicer" ]; \
  ln -sfn "${slicer_dir}" /opt/slicer; \
  ln -sfn /opt/slicer/Slicer /usr/local/bin/Slicer

RUN useradd -m -s /bin/bash -g users onyxia \
  && mkdir -p /home/onyxia/work /home/onyxia/.xpra \
  && chown -R onyxia:users /home/onyxia \
  && printf 'onyxia ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/onyxia \
  && chmod 0440 /etc/sudoers.d/onyxia

COPY premyom-slicer/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/opt/onyxia-init.sh"]
CMD []
