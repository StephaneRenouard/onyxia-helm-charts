FROM rocker/rstudio:4.5

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

RUN if ! getent group users >/dev/null 2>&1; then groupadd -g 100 users; fi \
  && if ! id -u onyxia >/dev/null 2>&1; then useradd -m -s /bin/bash -g users onyxia; fi \
  && mkdir -p /home/onyxia/work \
  && chown -R onyxia:users /home/onyxia \
  && printf 'onyxia ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/onyxia \
  && chmod 0440 /etc/sudoers.d/onyxia

COPY premyom-rstudio/image/onyxia-init.sh /opt/onyxia-init.sh
RUN chmod +x /opt/onyxia-init.sh

EXPOSE 8080

ENTRYPOINT ["tini", "--", "/opt/onyxia-init.sh"]
CMD ["/usr/lib/rstudio-server/bin/rserver", "--server-daemonize=0", "--www-address=0.0.0.0", "--www-port=8080", "--auth-none=1", "--server-user=onyxia", "--server-working-dir=/home/onyxia/work"]
