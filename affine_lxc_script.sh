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
$STD apt-get install -y gnupg
$STD apt-get install -y ca-certificates
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" >/etc/apt/sources.list.d/docker.list
$STD apt-get update
$STD apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
$STD systemctl enable docker
msg_ok "Installed Docker"

msg_info "Setting up Affine"
mkdir -p /opt/affine
cd /opt/affine

# Generate secure passwords
POSTGRES_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
REDIS_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  affine:
    image: ghcr.io/toeverything/affine-graphql:stable
    container_name: affine_selfhosted
    command:
      ['sh', '-c', 'node ./scripts/self-host-predeploy && node ./dist/index.js']
    ports:
      - '3010:3010'
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
    volumes:
      - ./config:/root/.affine/config
      - ./storage:/root/.affine/storage
    logging:
      driver: 'json-file'
      options:
        max-size: '1000m'
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - AFFINE_CONFIG_PATH=/root/.affine/config
      - REDIS_SERVER_HOST=redis
      - DATABASE_URL=postgres://affine:${POSTGRES_PASSWORD}@postgres:5432/affine
      - NODE_OPTIONS="--import=./scripts/register.js"
      - AFFINE_SERVER_HOST=localhost
      - AFFINE_SERVER_PORT=3010
      - AFFINE_SERVER_SUB_PATH=

  redis:
    image: redis:7-alpine
    container_name: affine_redis
    restart: unless-stopped
    volumes:
      - ./redis:/data
    healthcheck:
      test: ['CMD', 'redis-cli', '--raw', 'incr', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5
    command: redis-server --requirepass ${REDIS_PASSWORD}
    environment:
      - REDIS_PASSWORD=${REDIS_PASSWORD}

  postgres:
    image: postgres:16
    container_name: affine_postgres
    restart: unless-stopped
    volumes:
      - ./postgres:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U affine']
      interval: 10s
      timeout: 5s
      retries: 5
    environment:
      POSTGRES_USER: affine
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: affine
      PGDATA: /var/lib/postgresql/data/pgdata
EOF

# Create .env file
cat > .env << EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
COMPOSE_PROJECT_NAME=affine
EOF

msg_ok "Created Affine Configuration"

msg_info "Starting Affine Services"
$STD docker compose up -d
msg_ok "Started Affine Services"

msg_info "Creating Affine Management Scripts"
# Create update script
cat > /usr/local/bin/affine-update << 'EOF'
#!/bin/bash
cd /opt/affine
echo "Updating Affine..."
docker compose pull
docker compose up -d --force-recreate
docker image prune -f
echo "Affine updated successfully!"
EOF
chmod +x /usr/local/bin/affine-update

# Create backup script
cat > /usr/local/bin/affine-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/affine-backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

cd /opt/affine
echo "Creating backup..."
docker compose exec -T postgres pg_dump -U affine affine > $BACKUP_DIR/affine_db_$DATE.sql
tar -czf $BACKUP_DIR/affine_data_$DATE.tar.gz config storage
echo "Backup created: $BACKUP_DIR/affine_*_$DATE.*"
EOF
chmod +x /usr/local/bin/affine-backup

# Create restore script
cat > /usr/local/bin/affine-restore << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: affine-restore <backup_date>"
    echo "Available backups:"
    ls -la /opt/affine-backups/
    exit 1
fi

BACKUP_DIR="/opt/affine-backups"
DATE=$1

cd /opt/affine
echo "Stopping Affine services..."
docker compose down

echo "Restoring data..."
tar -xzf $BACKUP_DIR/affine_data_$DATE.tar.gz
docker compose up -d postgres redis
sleep 10
docker compose exec -T postgres psql -U affine -d affine < $BACKUP_DIR/affine_db_$DATE.sql

echo "Starting Affine services..."
docker compose up -d
echo "Restore completed!"
EOF
chmod +x /usr/local/bin/affine-restore

msg_ok "Created Management Scripts"

msg_info "Creating Systemd Service"
cat > /etc/systemd/system/affine.service << 'EOF'
[Unit]
Description=Affine
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/affine
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

$STD systemctl daemon-reload
$STD systemctl enable affine.service
msg_ok "Created Systemd Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove -y
$STD apt-get autoclean
msg_ok "Cleaned"