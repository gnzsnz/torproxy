# Tor Proxy Docker Image

A Docker image with a tor proxy and nyx to control it. This image is build
using [Tor Project apt repository](https://support.torproject.org/apt/tor-deb-repo/).

<!-- TOC -->

- [Tor Proxy Docker Image](#tor-proxy-docker-image)
  - [Build image](#build-image)
  - [Run torproxy container](#run-torproxy-container)
    - [Test that is actually working](#test-that-is-actually-working)
  - [Setting up Tor](#setting-up-tor)
  - [Setting up hidden services](#setting-up-hidden-services)
  - [Setting up nyx](#setting-up-nyx)
  - [Clean up](#clean-up)

<!-- /TOC -->

## Build image

To build the image you will need to edit the `.env-dist` file with your
preferred setup

```bash
cp .env-dist .env
nano .env
```

```bash
APT_PROXY=http://aptcacher:3142
UID=1000
GID=1000
```

Run `docker-compose config` and check that everything looks good. To build the
image using docker-compose you can do

```bash
docker compose build
```

Or with `docker build`

```bash
docker build --build-arg APT_PROXY="http://aptcacher:3142" \
--build-arg UID="$(id -u)" \
--build-arg GID="$(id -g)" \
-t gnzsnz/torproxy:latest .
```

UID and GID are used to map the host user to the debian-tor user in the
container. The image volumes will use this UID and GID.

APT_PROXY will be used if it's set. If the argument is empty the container will
contact ubuntu and tor project apt repositories directly.

## Run torproxy container

Simplest way is with compose `docker compose up`, you might modify the
`dist-docker-compose.yml` file provided.

Or alternatively with

```bash
docker run -it gnzsnz/torproxy:latest torproxy
```

You can setup these volumes:

- `/etc/tor` to set `torrc` file
- `/var/lib/tor/hidden_service` to store any manually created HS.
- `/run/tor` to set `control_auth_cookie`

sample compose file has examples to set the volumes.

### Test that is actually working

`docker compose ps` should show something like this. You are looking for State
"healthy"

```text
  Name                Command                 State               Ports
--------------------------------------------------------------------------------
torproxy   /usr/bin/tini -- /usr/bin/tor   Up (healthy)   0.0.0.0:9050->9050/tcp
```

To test a proxy connection you can run from the host or a computer that can
connect to the proxy

```bash
# no tor proxy
curl https://check.torproject.org/api/ip
{"IsTor":false,"IP":"48.213.75.164"}

# test tor proxy
curl --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip
{"IsTor":true,"IP":"46.165.245.154"}
```

## Setting up Tor

You can modify tor settings updating the `torrc` file provided in folder 'etc'.

For example you might want to modify these lines to allow specific IP ranges

```
# Allow local network
SOCKSPolicy accept 192.168.1.0/16
# Allow docker containers
SOCKSPolicy accept 172.17.0.0/16
```

`torrc` file is  stored in `/etc/tor` volume.

**Reference**:

  * https://2019.www.torproject.org/docs/tor-manual.html.en

## Setting up hidden services

To setup a hidden service you will need to modify torrc file. You can either
use as a template the `hidden_service.conf` provided in directory etc/torrc.d

you can uncomment line `%include /etc/tor/torrc.d/*.conf` to include hidden
service setup in `etc/torrc.d`.

Hidden service keys will be stored in volumen tor_service. You can import
existing keys by coping the files in the `hidden_services` folder.

**References**:

* https://community.torproject.org/onion-services/setup/
* https://2019.www.torproject.org/docs/tor-onion-service.html.en
* https://riseup.net/hi/security/network-security/tor/onionservices-best-practices
* Onionscan -> https://github.com/s-rah/onionscan
* https://gitlab.torproject.org/legacy/trac/-/wikis/doc/OperationalSecurity

## Setting up nyx

Nyx is setup in the torproxy docker container. A default config file is
available in folder nyx. You can adjust it's values before build, or directly
in the container. By default nyx will use cookie authentication.

To run nyx you need to `docker exec -it torproxy nyx`

Once you are connected to nyx you can control your tor client, configuration
and services.

**Reference**:

- [https://nyx.torproject.org/#configuration](https://nyx.torproject.org/#configuration)

## Clean up

To clean up everything

```bash
docker compose down --rmi all -v
```
