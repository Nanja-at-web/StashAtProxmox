#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2026 community-scripts ORG
# Author: OpenAI
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://docs.stashapp.cc/

APP="StashApp"
var_tags="${var_tags:-media;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/stash ]]; then
    msg_error "No ${APP} installation found!"
    exit
  fi

  msg_info "Updating base system"
  $STD apt update
  $STD apt upgrade -y
  msg_ok "Updated base system"

  msg_info "Updating Docker Engine"
  $STD apt install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
  msg_ok "Updated Docker Engine"

  if [[ ! -f /opt/stash/docker-compose.yml ]]; then
    msg_error "Missing /opt/stash/docker-compose.yml"
    exit
  fi

  msg_info "Updating StashApp containers"
  cd /opt/stash || exit
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated StashApp"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9999${CL}"
echo -e "${INFO}${YW} Recommended library mount inside the container:${CL}"
echo -e "${TAB}${BGN}/mnt/stash-library${CL}"
