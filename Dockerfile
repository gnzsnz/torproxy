ARG BASE_VERSION
FROM ubuntu:${BASE_VERSION:-latest}

ARG BASE_VERSION
ARG APT_PROXY
ARG UID
ARG GID
ARG USER=debian-tor
ARG OLD_UID=101
ARG OLD_GID=101
RUN if [ -n "$APT_PROXY" ]; then \
      echo 'Acquire::http { Proxy "'$APT_PROXY'"; }'  \
      | tee /etc/apt/apt.conf.d/01proxy \
    ;fi \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates apt-transport-https gpg gpg-agent wget tini\
    && wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | apt-key add - \
    && echo "deb [arch=amd64] https://deb.torproject.org/torproject.org ${BASE_VERSION} main" | tee /etc/apt/sources.list.d/torproject.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive  apt-get install --no-install-recommends -y \
    tor deb.torproject.org-keyring nyx \
    && rm -rf /var/lib/apt/lists/* \
    && if [ -n "$UID" -a -n "$GID" ]; then \
      echo 'Setting UID:'$UID' and GID:'$GID \
      && usermod -u $UID $USER \
      && groupmod -g $GID $USER \
      && find /etc/tor/ -group $OLD_GID -exec chgrp -h debian-tor {} + \
      && find /etc/tor/ -user $OLD_UID -exec chown -h debian-tor {} + \
      && find /var/lib/tor/ -group $OLD_GID -exec chgrp -h debian-tor {} + \
      && find /var/lib/tor/ -user $OLD_UID -exec chown -h debian-tor {} + \
    ; fi

COPY --chown=$USER:$USER etc/* /etc/tor/
COPY --chown=$USER:$USER hidden_services/* /var/lib/tor/
COPY --chown=$USER:$USER nyx/config /var/lib/tor/.nyx/

HEALTHCHECK --interval=20s --timeout=15s --start-period=10s \
            CMD tor-resolve -v google.com || exit 1

USER $USER
CMD ["/usr/bin/tor"]
ENTRYPOINT ["/usr/bin/tini", "--"]
EXPOSE 9050
VOLUME ["/etc/tor", "/var/lib/tor"]
