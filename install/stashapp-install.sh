#!/usr/bin/env bash

# Copyright (c) 2026 community-scripts ORG
# Author: OpenAI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.stashapp.cc/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

DOCKER_LATEST_VERSION=$(get_latest_github_release "moby/moby")
STASH_LATEST_VERSION=$(get_latest_github_release "stashapp/stash")
DEFAULT_LIBRARY_PATH="/mnt/stash-library"
STASH_PATH="/opt/stash"

msg_info "Installing Docker $DOCKER_LATEST_VERSION"
mkdir -p /etc/docker
cat <<'JSON' >/etc/docker/daemon.json
{
  "log-driver": "journald"
}
JSON
$STD sh <(curl -fsSL https://get.docker.com)
msg_ok "Installed Docker $DOCKER_LATEST_VERSION"

msg_info "Preparing StashApp directories"
mkdir -p ${STASH_PATH}/{config,metadata,cache,blobs,generated}
msg_ok "Prepared StashApp directories"

read -r -p "${TAB3}Library path inside this container [${DEFAULT_LIBRARY_PATH}]: " LIBRARY_PATH
LIBRARY_PATH="${LIBRARY_PATH:-$DEFAULT_LIBRARY_PATH}"
mkdir -p "$LIBRARY_PATH"
echo "$LIBRARY_PATH" >/root/.stash-library-path
msg_ok "Using library path $LIBRARY_PATH"

msg_info "Writing Docker Compose configuration"
cat <<EOF2 >${STASH_PATH}/docker-compose.yml
services:
  stash:
    image: stashapp/stash:latest
    container_name: stash
    restart: unless-stopped
    ports:
      - "9999:9999"
    environment:
      STASH_STASH: /data/
      STASH_GENERATED: /generated/
      STASH_METADATA: /metadata/
      STASH_CACHE: /cache/
      STASH_PORT: 9999
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ${STASH_PATH}/config:/root/.stash
      - ${LIBRARY_PATH}:/data
      - ${STASH_PATH}/metadata:/metadata
      - ${STASH_PATH}/cache:/cache
      - ${STASH_PATH}/blobs:/blobs
      - ${STASH_PATH}/generated:/generated
EOF2
msg_ok "Created Docker Compose configuration"

msg_info "Starting StashApp $STASH_LATEST_VERSION"
cd "$STASH_PATH" || exit
$STD docker compose up -d
msg_ok "Started StashApp $STASH_LATEST_VERSION"

cat <<EOF2 >/etc/motd
StashApp is installed.

Web UI: http://$(hostname -I | awk '{print $1}'):9999
Library mount inside this CT: ${LIBRARY_PATH}

If you are using a Proxmox host bind mount for your NAS share,
map it to ${LIBRARY_PATH} and then add /data in Stash > Settings > Library.
EOF2

motd_ssh
customize
cleanup_lxc
