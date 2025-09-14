ARG BASE_VERSION=noble
FROM ubuntu:$BASE_VERSION

ARG BASE_VERSION
ARG APT_PROXY
ARG UID=1000
ARG GID=1000
ARG USER=debian-tor
ARG OLD_UID=101
ARG OLD_GID=101
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008
RUN if [ -n "$APT_PROXY" ]; then \
      echo 'Acquire::http { Proxy "'$APT_PROXY'"; }'  \
      | tee /etc/apt/apt.conf.d/01proxy \
    ;fi \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates apt-transport-https gpg wget tini\
    && wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org ${BASE_VERSION} main" | tee /etc/apt/sources.list.d/torproject.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    tor deb.torproject.org-keyring nyx \
    && apt-get purge -qy gpg wget \
    && apt-get autoremove -qy \
    && rm -rf /var/lib/apt/lists/* \
    && if id ubuntu; then \
      userdel -rf ubuntu \
    ;fi \
    && if [ -n "$UID" ] && [ -n "$GID" ]; then \
      echo 'Setting UID:'$UID' and GID:'$GID \
      && usermod -u $UID $USER \
      && groupmod -g $GID $USER \
      && find /etc/tor/ -group $OLD_GID -exec chgrp -h debian-tor {} + \
      && find /etc/tor/ -user $OLD_UID -exec chown -h debian-tor {} + \
      && find /var/lib/tor/ -group $OLD_GID -exec chgrp -h debian-tor {} + \
      && find /var/lib/tor/ -user $OLD_UID -exec chown -h debian-tor {} + \
    ; fi \
    && mkdir /run/tor \
    && chown -R $UID:$GID /run/tor \
    && chmod -R 750 /run/tor


COPY --chown=$USER:$USER etc/* /etc/tor/
COPY --chown=$USER:$USER nyx/config /var/lib/tor/.nyx/

USER $USER

EXPOSE 9050 9051
VOLUME /etc/tor
VOLUME /var/lib/tor
VOLUME /run/tor

CMD ["/usr/bin/tor"]
ENTRYPOINT ["/usr/bin/tini", "--"]

HEALTHCHECK --interval=20s --timeout=15s --start-period=10s \
    CMD tor-resolve -v google.com || exit 1
