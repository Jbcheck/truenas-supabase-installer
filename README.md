# TrueNAS Supabase Installer

Automated installation script for self-hosted Supabase on TrueNAS Scale systems.

## Features

- 🚀 **One-click installation** of complete Supabase stack
- 💾 **Persistent storage** using ZFS datasets
- 🔧 **Auto-configuration** with secure key generation
- 📊 **Health monitoring** and management scripts
- 🔄 **Systemd integration** for automatic startup
- 📦 **Backup utilities** for data protection
- 🌐 **Ready for Cloudflare tunnel** integration

## Components Installed

- PostgreSQL 15 (Database)
- PostgREST (API)
- GoTrue (Authentication)
- Supabase Studio (Dashboard)
- Kong (API Gateway)
- Storage API
- Realtime Server
- Inbucket (Email testing)

## Prerequisites

- TrueNAS Scale system
- Docker and docker-compose installed
- ZFS pool named `pool1`
- Root access

## Quick Start

1. **Create Supabase dataset** (if not already created):
   ```bash
   # Using TrueNAS web interface or CLI
   zfs create pool1/supabase
   ```

2. **Download and run the installer**:
   ```bash
   wget https://raw.githubusercontent.com/Jbcheck/truenas-supabase-installer/main/install-supabase.sh
   chmod +x install-supabase.sh
   sudo ./install-supabase.sh
   ```

3. **Access your Supabase instance**:
   - Studio: `http://your-truenas-ip:3000`
   - API: `http://your-truenas-ip:8000`
   - Database: `your-truenas-ip:5432`

## Configuration

The script automatically:
- Generates secure passwords and JWT secrets
- Creates environment configuration
- Sets up persistent storage volumes
- Configures port mappings
- Creates systemd service for auto-start
- Generates management scripts

## Management

After installation, you can manage Supabase using:

```bash
# System service controls
sudo systemctl start supabase
sudo systemctl stop supabase
sudo systemctl restart supabase
sudo systemctl status supabase

# Health check
/mnt/pool1/supabase/health-check.sh

# Backup
/mnt/pool1/supabase/backup-supabase.sh

# Restart services
/mnt/pool1/supabase/restart-supabase.sh
```

## Directory Structure

After installation:
```
/mnt/pool1/supabase/
├── supabase/              # Cloned repository
│   └── docker/            # Docker compose files
├── volumes/               # Persistent data
│   ├── db/data/          # PostgreSQL data
│   ├── storage/          # File storage
│   └── logs/             # Log files
├── backup-supabase.sh     # Backup script
├── health-check.sh        # Health monitoring
└── restart-supabase.sh    # Service restart
```

## Integration with Applications

Use these environment variables in your applications:

```env
SUPABASE_URL=http://your-truenas-ip:8000
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

## External Access via Cloudflare Tunnel

To make your Supabase instance accessible from the internet:

1. **Configure cloudflared** (if not already done):
   ```yaml
   # Add to your tunnel configuration
   ingress:
     - hostname: supabase.yourdomain.com
       service: http://localhost:3000
     - hostname: supabase-api.yourdomain.com
       service: http://localhost:8000
   ```

2. **Update environment variables** for external access:
   ```env
   SUPABASE_URL=https://supabase-api.yourdomain.com
   ```

## Backup and Recovery

The installer creates an automated backup script:

```bash
# Run backup
/mnt/pool1/supabase/backup-supabase.sh

# Backups are stored in:
/mnt/pool1/backups/supabase/
```

Backup includes:
- Complete PostgreSQL database dump
- Storage files (compressed)
- Configuration files

## Troubleshooting

### Check service status
```bash
/mnt/pool1/supabase/health-check.sh
```

### View logs
```bash
cd /mnt/pool1/supabase/supabase/docker
docker-compose logs -f
```

### Restart services
```bash
/mnt/pool1/supabase/restart-supabase.sh
```

### Port conflicts
If ports 3000, 8000, or 5432 are in use, modify the script variables:
- `SUPABASE_PORT_STUDIO=3000`
- `SUPABASE_PORT_API=8000`
- `POSTGRES_PORT=5432`

## Security Notes

- 🔐 All passwords and keys are auto-generated securely
- 🗄️ Database is only accessible locally by default
- 🌐 Use Cloudflare tunnel for secure external access
- 💾 Regular backups are essential
- 🔑 Store your credentials securely

## Updates

To update Supabase:

1. **Stop services**:
   ```bash
   sudo systemctl stop supabase
   ```

2. **Update repository**:
   ```bash
   cd /mnt/pool1/supabase/supabase
   git pull
   ```

3. **Restart services**:
   ```bash
   sudo systemctl start supabase
   ```

## Support

For issues related to:
- **This installer**: Open an issue on GitHub
- **Supabase itself**: Check [Supabase documentation](https://supabase.com/docs)
- **TrueNAS**: Consult [TrueNAS documentation](https://www.truenas.com/docs/)

## License

MIT License - Feel free to modify and distribute.

---

**Happy self-hosting with Supabase on TrueNAS! 🚀**