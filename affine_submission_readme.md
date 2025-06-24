# Affine LXC Container Script

This script creates an LXC container running Affine, a next-generation knowledge base that combines note-taking, wikis, and databases in one collaborative workspace.

## Features

- **Complete Affine Installation**: Self-hosted Affine instance with PostgreSQL and Redis
- **Docker-based Deployment**: Uses official Affine Docker images for stability
- **Automatic Service Management**: Systemd service ensures Affine starts on boot
- **Built-in Management Tools**: Update, backup, and restore scripts included
- **Secure Configuration**: Auto-generated passwords and proper container networking

## System Requirements

- **CPU**: 2 cores minimum (recommended for responsive performance)
- **RAM**: 4GB (sufficient for most use cases, can be reduced to 2GB for light usage)
- **Storage**: 8GB base + additional space for user data
- **Network**: Standard LXC networking with port 3010 exposed

## Installation

Run the following command in your Proxmox VE shell:

```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/affine.sh)"
```

## Post-Installation

1. **Access Affine**: Navigate to `http://[container-ip]:3010`
2. **Initial Setup**: Follow the web-based setup wizard
3. **Create Admin Account**: Set up your first user account

## Management Commands

The script installs several management utilities:

- `affine-update` - Update Affine to the latest version
- `affine-backup` - Create a backup of your Affine data and database
- `affine-restore <date>` - Restore from a previous backup

## File Locations

- **Application**: `/opt/affine/`
- **Configuration**: `/opt/affine/config/`
- **User Data**: `/opt/affine/storage/`
- **Database Data**: `/opt/affine/postgres/`
- **Backups**: `/opt/affine-backups/`

## Architecture

The deployment includes:
- **Affine Application Server**: Main application container
- **PostgreSQL 16**: Database for storing workspace data
- **Redis 7**: Caching and session management
- **Docker Compose**: Container orchestration
- **Systemd Service**: Automatic startup and management

## Networking

- **Port 3010**: Web interface (HTTP)
- **Internal Network**: Database and Redis communicate internally
- **No External Dependencies**: Fully self-contained deployment

## Security Notes

- Passwords are automatically generated using OpenSSL
- Database access is restricted to internal container network
- Redis requires authentication
- No default credentials are used

## Backup Strategy

Regular backups include:
- PostgreSQL database dump
- User-uploaded files and configurations
- Timestamped storage for easy management

## Troubleshooting

### Service Status
```bash
systemctl status affine
docker compose -f /opt/affine/docker-compose.yml ps
```

### View Logs
```bash
docker compose -f /opt/affine/docker-compose.yml logs
```

### Restart Services
```bash
systemctl restart affine
```

## Updates

Affine can be updated using the built-in update script:
```bash
affine-update
```

This will:
1. Pull the latest container images
2. Recreate containers with new images
3. Clean up old images
4. Preserve all user data

## Contributing

This script follows the community-scripts standards for:
- Error handling and logging
- Resource allocation
- Security best practices
- User experience consistency

## License

MIT License - See the community-scripts repository for full license text.

## Support

For issues related to:
- **Script Installation**: Community-scripts repository issues
- **Affine Usage**: Official Affine documentation at https://docs.affine.pro/
- **Container Management**: Proxmox VE documentation