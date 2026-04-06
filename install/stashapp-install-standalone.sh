#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
LIBRARY_PATH="${LIBRARY_PATH:-/mnt/stash-library}"
STASH_PATH="/opt/stash"

apt update
apt install -y curl ca-certificates

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable docker >/dev/null 2>&1 || true
systemctl start docker >/dev/null 2>&1 || true

mkdir -p "${STASH_PATH}/config" \
         "${STASH_PATH}/metadata" \
         "${STASH_PATH}/cache" \
         "${STASH_PATH}/blobs" \
         "${STASH_PATH}/generated" \
         "${LIBRARY_PATH}"

echo "${LIBRARY_PATH}" >/root/.stash-library-path

cat >"${STASH_PATH}/docker-compose.yml" <<EOF
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
EOF

cd "${STASH_PATH}"
docker compose pull
docker compose up -d

IP_ADDR=$(hostname -I | awk '{print $1}')
cat >/etc/motd <<EOF
StashApp is installed.

Web UI: http://${IP_ADDR}:9999
Library mount inside this CT: ${LIBRARY_PATH}

If you are using a Proxmox host bind mount for your NAS share,
map it to ${LIBRARY_PATH} and then add /data in Stash > Settings > Library.
EOF

echo "StashApp installed successfully. Web UI: http://${IP_ADDR}:9999"
