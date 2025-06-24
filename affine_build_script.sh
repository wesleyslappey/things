#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 community-scripts
# Author: community-scripts  
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    ___    __________ _____   ______
   /   |  / ____/ ____/  _/  / ____/
  / /| | / /_  / /_   / /   / __/   
 / ___ |/ __/ / __/ _/ /   / /___   
/_/  |_/_/   /_/   /___/  /_____/   
                                   
EOF
}
header_info
echo -e "Loading..."
APP="Affine"
var_disk="8"
var_cpu="2"
var_ram="4096"
var_os="debian"
var_version="12"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /opt/affine ]]; then
  msg_error "No ${APP} Installation Found!"
  exit
fi
msg_info "Updating ${APP}"
cd /opt/affine
docker compose pull
docker compose up -d --force-recreate
docker image prune -f
msg_ok "Updated ${APP}"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:3010${CL} \\n"
echo -e "Management Commands:
         ${BL}affine-update${CL} - Update Affine to latest version
         ${BL}affine-backup${CL} - Create backup of Affine data
         ${BL}affine-restore <date>${CL} - Restore from backup \\n"