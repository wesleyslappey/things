#!/usr/bin/env bash

# Copyright (c) 2025 community-scripts
# Author: community-scripts
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y gpg
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD bash <(curl -sSL https://get.docker.com)
$STD systemctl enable docker
$STD systemctl start docker
msg_ok "Installed Docker"

msg_info "Installing Docker Compose"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
$STD curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$STD chmod +x /usr/local/bin/docker-compose
msg_ok "Installed Docker Compose"

msg_info "Setting up Affine"
mkdir -p /opt/affine
cd /opt/affine

msg_info "Downloading Affine Configuration Files"
$STD wget -O docker-compose.yml https://raw.githubusercontent.com/toeverything/AFFiNE/canary/tools/docker-compose/docker-compose.yml
$STD wget -O .env https://raw.githubusercontent.com/toeverything/AFFiNE/canary/tools/docker-compose/.env.template

# Configure environment variables
cat > .env << EOF
# AFFiNE Configuration
AFFINE_SERVER_HOST=localhost
AFFINE_SERVER_PORT=3010
AFFINE_SERVER_HTTPS=false
POSTGRES_USER=affine
POSTGRES_PASSWORD=$(openssl rand -base64 20)
POSTGRES_DB=affine
POSTGRES_PORT=5432
REDIS_SERVER_HOST=redis
REDIS_SERVER_PORT=6379
REDIS_SERVER_PASSWORD=
NODE_ENV=production
AFFINE_ENV=selfhosted
DATABASE_URL=postgres://affine:\${POSTGRES_PASSWORD}@postgres:5432/affine
REDIS_SERVER_URL=redis://redis:6379
# Data persistence
AFFINE_CONFIG_PATH=./config
AFFINE_DATA_PATH=./data
POSTGRES_DATA_PATH=./postgres
REDIS_DATA_PATH=./redis
EOF

msg_ok "Downloaded Affine Configuration Files"

msg_info "Creating Affine systemd service"
cat > /etc/systemd/system/affine.service << EOF
[Unit]
Description=Affine
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/affine
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl enable affine.service
msg_ok "Created Affine systemd service"

msg_info "Starting Affine"
cd /opt/affine
$STD docker-compose up -d
msg_ok "Started Affine"

msg_info "Creating Update Script"
cat > /opt/affine/update.sh << 'EOF'
#!/bin/bash
cd /opt/affine
echo "Pulling latest Affine images..."
docker-compose pull
echo "Recreating containers..."
docker-compose up -d --force-recreate
echo "Cleaning up old images..."
docker image prune -f
echo "Affine update complete!"
EOF
chmod +x /opt/affine/update.sh
msg_ok "Created Update Script"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
