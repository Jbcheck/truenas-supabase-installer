#!/bin/bash
# Supabase Self-Hosted Installation Script for TrueNAS Scale
# This script automates the installation of Supabase on your TrueNAS system

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUPABASE_DIR="/mnt/pool1/supabase"
SUPABASE_PORT_STUDIO=3000
SUPABASE_PORT_API=8000
POSTGRES_PORT=5432

echo -e "${BLUE}🚀 Starting Supabase Self-Hosted Installation on TrueNAS Scale${NC}"
echo "============================================================"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

# Check if dataset exists
if [ ! -d "$SUPABASE_DIR" ]; then
    print_error "Supabase dataset not found at $SUPABASE_DIR"
    print_error "Please create the dataset first: zfs create pool1/supabase"
    exit 1
fi

print_status "Supabase dataset found at $SUPABASE_DIR"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not available"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose is not installed or not available"
    exit 1
fi

print_status "Docker and docker-compose are available"

# Create directory structure
print_status "Creating directory structure..."
cd "$SUPABASE_DIR"

# Clone Supabase repository if not already present
if [ ! -d "supabase" ]; then
    print_status "Cloning Supabase repository..."
    git clone --depth 1 https://github.com/supabase/supabase.git
else
    print_status "Supabase repository already exists, updating..."
    cd supabase && git pull && cd ..
fi

cd supabase/docker

# Create volumes directory
print_status "Creating volume directories..."
mkdir -p "$SUPABASE_DIR/volumes/db/data"
mkdir -p "$SUPABASE_DIR/volumes/storage"
mkdir -p "$SUPABASE_DIR/volumes/logs"

# Set permissions
chmod -R 777 "$SUPABASE_DIR/volumes/"

# Generate secure passwords and keys
print_status "Generating secure configuration..."

# Generate random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)

# Function to generate Supabase keys
generate_supabase_keys() {
    # Install Supabase CLI if not present
    if ! command -v supabase &> /dev/null; then
        print_status "Installing Supabase CLI..."
        curl -o- https://raw.githubusercontent.com/supabase/cli/main/install.sh | bash
        export PATH=$PATH:~/.local/bin
    fi
    
    # Generate keys
    ANON_KEY=$(supabase gen keys --anon 2>/dev/null | grep "anon key:" | awk '{print $3}')
    SERVICE_ROLE_KEY=$(supabase gen keys --service-role 2>/dev/null | grep "service_role key:" | awk '{print $3}')
    
    # Fallback if CLI generation fails
    if [ -z "$ANON_KEY" ] || [ -z "$SERVICE_ROLE_KEY" ]; then
        print_warning "Using fallback key generation method"
        ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
        SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
    fi
}

generate_supabase_keys

# Create .env file
print_status "Creating environment configuration..."
cat > .env << EOF
############
# Secrets
# DO NOT CHANGE THESE IN PRODUCTION WITHOUT PROPER MIGRATION
############

POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY

############
# Database
############
POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres

############
# API Proxy
############
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443

############
# API
############
POSTGREST_PORT=3000
SUPABASE_API_PORT=8000

############
# Auth
############
GOTRUE_PORT=9999
GOTRUE_SITE_URL=http://localhost:3000
GOTRUE_URI_ALLOW_LIST=
GOTRUE_DISABLE_SIGNUP=false
GOTRUE_JWT_ADMIN_ROLES=service_role
GOTRUE_JWT_AUD=authenticated
GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated
GOTRUE_JWT_EXP=3600
GOTRUE_EXTERNAL_EMAIL_ENABLED=true
GOTRUE_MAILER_AUTOCONFIRM=true
GOTRUE_SMTP_ADMIN_EMAIL=admin@example.com
GOTRUE_SMTP_HOST=supabase-mail
GOTRUE_SMTP_PORT=2500
GOTRUE_SMTP_USER=fake_mail_user
GOTRUE_SMTP_PASS=fake_mail_password
GOTRUE_SMTP_SENDER_NAME=fake_sender

############
# Studio
############
STUDIO_PORT=3000
SUPABASE_PUBLIC_URL=http://localhost:8000

############
# Inbucket
############
INBUCKET_PORT=9000
INBUCKET_SMTP_PORT=2500

############
# Storage
############
STORAGE_PORT=5000
FILE_SIZE_LIMIT=52428800

############
# Analytics
############
LOGFLARE_PORT=4000
LOGFLARE_DB_USERNAME=postgres
LOGFLARE_DB_DATABASE=postgres

############
# Vector/Embeddings
############
VECTOR_PORT=54321

############
# TrueNAS Specific Settings
############
COMPOSE_PROJECT_NAME=supabase
EOF

# Modify docker-compose.yml for persistent storage
print_status "Configuring Docker Compose for persistent storage..."

# Backup original
cp docker-compose.yml docker-compose.yml.backup

# Update docker-compose.yml with persistent volumes
cat > docker-compose-truenas.yml << EOF
# TrueNAS-specific override for Supabase
version: "3.8"

services:
  db:
    volumes:
      - $SUPABASE_DIR/volumes/db/data:/var/lib/postgresql/data:Z
    ports:
      - "$POSTGRES_PORT:5432"

  storage:
    volumes:
      - $SUPABASE_DIR/volumes/storage:/var/lib/storage:z

  studio:
    ports:
      - "$SUPABASE_PORT_STUDIO:3000"

  kong:
    ports:
      - "$SUPABASE_PORT_API:8000"
      - "8443:8443"

  inbucket:
    ports:
      - "9000:9000"
EOF

# Check for port conflicts
print_status "Checking for port conflicts..."
for port in $SUPABASE_PORT_STUDIO $SUPABASE_PORT_API $POSTGRES_PORT; do
    if netstat -tuln | grep -q ":$port "; then
        print_warning "Port $port is already in use. Please stop the conflicting service or modify the port in the script."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
done

# Pull Docker images
print_status "Pulling Docker images (this may take a while)..."
docker-compose -f docker-compose.yml -f docker-compose-truenas.yml pull

# Start Supabase
print_status "Starting Supabase services..."
docker-compose -f docker-compose.yml -f docker-compose-truenas.yml up -d

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Check if services are running
print_status "Checking service status..."
docker-compose -f docker-compose.yml -f docker-compose-truenas.yml ps

# Create systemd service for auto-start
print_status "Creating systemd service for auto-start..."
cat > /etc/systemd/system/supabase.service << EOF
[Unit]
Description=Supabase Self-Hosted
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$SUPABASE_DIR/supabase/docker
ExecStart=/usr/bin/docker-compose -f docker-compose.yml -f docker-compose-truenas.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.yml -f docker-compose-truenas.yml down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable supabase.service

# Create management scripts
print_status "Creating management scripts..."

# Backup script
cat > "$SUPABASE_DIR/backup-supabase.sh" << 'EOF'
#!/bin/bash
# Supabase Backup Script

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/mnt/pool1/backups/supabase"
SUPABASE_DIR="/mnt/pool1/supabase"

mkdir -p $BACKUP_DIR

echo "Creating Supabase backup: $DATE"

# Database backup
docker exec supabase-db-1 pg_dumpall -U postgres > $BACKUP_DIR/supabase_db_$DATE.sql

# Storage backup
tar -czf $BACKUP_DIR/supabase_storage_$DATE.tar.gz $SUPABASE_DIR/volumes/storage

# Config backup
cp $SUPABASE_DIR/supabase/docker/.env $BACKUP_DIR/env_$DATE.backup

echo "Backup completed: $DATE"
echo "Files created:"
echo "  - Database: $BACKUP_DIR/supabase_db_$DATE.sql"
echo "  - Storage: $BACKUP_DIR/supabase_storage_$DATE.tar.gz"
echo "  - Config: $BACKUP_DIR/env_$DATE.backup"
EOF

chmod +x "$SUPABASE_DIR/backup-supabase.sh"

# Health check script
cat > "$SUPABASE_DIR/health-check.sh" << 'EOF'
#!/bin/bash
# Supabase Health Check Script

SUPABASE_DIR="/mnt/pool1/supabase"

echo "=== Supabase Health Check ==="
echo "Date: $(date)"
echo

# Check if containers are running
echo "Container Status:"
cd $SUPABASE_DIR/supabase/docker
docker-compose -f docker-compose.yml -f docker-compose-truenas.yml ps

echo
echo "Database Connection:"
docker exec supabase-db-1 pg_isready -U postgres

echo
echo "API Health:"
curl -s http://localhost:8000/health || echo "API not responding"

echo
echo "Studio Health:"
curl -s http://localhost:3000 > /dev/null && echo "Studio OK" || echo "Studio not responding"

echo
echo "Storage Usage:"
df -h $SUPABASE_DIR/volumes/

echo
echo "=== Recent Logs ==="
docker-compose -f docker-compose.yml -f docker-compose-truenas.yml logs --tail=10
EOF

chmod +x "$SUPABASE_DIR/health-check.sh"

# Create restart script
cat > "$SUPABASE_DIR/restart-supabase.sh" << 'EOF'
#!/bin/bash
# Supabase Restart Script

SUPABASE_DIR="/mnt/pool1/supabase"

echo "Restarting Supabase services..."
cd $SUPABASE_DIR/supabase/docker

docker-compose -f docker-compose.yml -f docker-compose-truenas.yml down
sleep 5
docker-compose -f docker-compose.yml -f docker-compose-truenas.yml up -d

echo "Supabase restarted"
EOF

chmod +x "$SUPABASE_DIR/restart-supabase.sh"

# Final status check
sleep 10
print_status "Final health check..."

# Get container status
CONTAINERS_RUNNING=$(docker-compose -f docker-compose.yml -f docker-compose-truenas.yml ps --filter="status=running" --quiet | wc -l)
CONTAINERS_TOTAL=$(docker-compose -f docker-compose.yml -f docker-compose-truenas.yml ps --quiet | wc -l)

echo
echo "============================================================"
echo -e "${GREEN}🎉 Supabase Installation Complete!${NC}"
echo "============================================================"
echo
echo "📊 Service Status:"
echo "  - Containers running: $CONTAINERS_RUNNING/$CONTAINERS_TOTAL"
echo
echo "🌐 Access URLs:"
echo "  - Supabase Studio: http://$(hostname -I | awk '{print $1}'):$SUPABASE_PORT_STUDIO"
echo "  - API Endpoint: http://$(hostname -I | awk '{print $1}'):$SUPABASE_PORT_API"
echo "  - PostgreSQL: $(hostname -I | awk '{print $1}'):$POSTGRES_PORT"
echo "  - Email Testing: http://$(hostname -I | awk '{print $1}'):9000"
echo
echo "🔐 Credentials:"
echo "  - Database Password: $POSTGRES_PASSWORD"
echo "  - JWT Secret: $JWT_SECRET"
echo "  - Anon Key: $ANON_KEY"
echo "  - Service Role Key: $SERVICE_ROLE_KEY"
echo
echo "📁 Important Files:"
echo "  - Config: $SUPABASE_DIR/supabase/docker/.env"
echo "  - Data: $SUPABASE_DIR/volumes/"
echo "  - Backup Script: $SUPABASE_DIR/backup-supabase.sh"
echo "  - Health Check: $SUPABASE_DIR/health-check.sh"
echo "  - Restart Script: $SUPABASE_DIR/restart-supabase.sh"
echo
echo "🛠️ Management Commands:"
echo "  - Start: systemctl start supabase"
echo "  - Stop: systemctl stop supabase"
echo "  - Restart: systemctl restart supabase"
echo "  - Status: systemctl status supabase"
echo "  - Health Check: $SUPABASE_DIR/health-check.sh"
echo "  - Backup: $SUPABASE_DIR/backup-supabase.sh"
echo
echo "🔗 Integration:"
echo "  - Add to your apps:"
echo "    SUPABASE_URL=http://$(hostname -I | awk '{print $1}'):$SUPABASE_PORT_API"
echo "    SUPABASE_ANON_KEY=$ANON_KEY"
echo "    SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY"
echo
echo "⚠️  Important Notes:"
echo "  - Save your credentials securely!"
echo "  - Configure your Cloudflare tunnel for external access"
echo "  - Run regular backups with the backup script"
echo "  - Monitor logs: docker-compose logs -f"
echo
echo "🎯 Next Steps:"
echo "  1. Open Supabase Studio in your browser"
echo "  2. Create your first project/database"
echo "  3. Set up authentication providers"
echo "  4. Configure Row Level Security (RLS)"
echo "  5. Create your application schemas"
echo
echo "Happy building with Supabase! 🚀"
echo "============================================================"