#!/bin/bash

# Invoice Ninja Production Deployment Script
# For use with external Nginx Proxy Manager

set -e

echo "========================================"
echo "Invoice Ninja Production Deployment"
echo "With Nginx Proxy Manager Integration"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if .env.production exists
if [ ! -f .env.production ]; then
    echo -e "${RED}Error: .env.production not found!${NC}"
    echo ""
    echo "Please:"
    echo "1. Copy .env.production.example to .env.production"
    echo "2. Update all CHANGE_THIS values"
    echo "3. Set your domain, passwords, and email settings"
    exit 1
fi

# Check for required values in .env.production
if grep -q "CHANGE_THIS\|GENERATE_NEW_KEY_HERE\|yourdomain.com" .env.production; then
    echo -e "${YELLOW}Warning: .env.production contains placeholder values!${NC}"
    echo ""
    echo "Please update these values:"
    grep -n "CHANGE_THIS\|GENERATE_NEW_KEY_HERE\|yourdomain.com" .env.production | head -10
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Generate APP_KEY if needed
if grep -q "GENERATE_NEW_KEY_HERE" .env.production; then
    echo -e "${BLUE}Generating APP_KEY...${NC}"
    NEW_KEY=$(docker run --rm invoiceninja/invoiceninja-debian php artisan key:generate --show)
    sed -i.bak "s|APP_KEY=.*|APP_KEY=$NEW_KEY|" .env.production
    echo -e "${GREEN}✓ APP_KEY generated${NC}"
fi

echo ""
echo -e "${BLUE}=== Starting Services ===${NC}"

# Stop existing containers if running
if [ -f docker-compose.yml ]; then
    echo "Stopping existing development containers..."
    docker compose down 2>/dev/null || true
fi

# Start production containers
echo "Starting production containers..."
docker compose -f docker-compose.production.yml up -d

echo ""
echo -e "${BLUE}=== Waiting for Services ===${NC}"

# Wait for MySQL to be ready
echo -n "Waiting for MySQL to be ready"
for i in {1..30}; do
    if docker compose -f docker-compose.production.yml exec mysql mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} &>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Wait for app to be ready
echo -n "Waiting for PHP-FPM to be ready"
for i in {1..30}; do
    if docker compose -f docker-compose.production.yml exec app pgrep -f "php-fpm: master process" &>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${BLUE}=== Applying Security Bypasses ===${NC}"
read -p "Apply paywall bypasses for testing? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Apply bypasses
    if [ -f apply_bypass_complete.sh ]; then
        echo "Applying complete bypass..."
        # Modify script to use production compose file
        sed 's/docker compose/docker compose -f docker-compose.production.yml/g' apply_bypass_complete.sh > apply_bypass_production.sh
        chmod +x apply_bypass_production.sh
        ./apply_bypass_production.sh
        rm apply_bypass_production.sh
        
        # Also apply UI removal
        if [ -f remove_license_ui.sh ]; then
            echo "Removing license UI elements..."
            sed 's/docker compose/docker compose -f docker-compose.production.yml/g' remove_license_ui.sh > remove_ui_production.sh
            chmod +x remove_ui_production.sh
            ./remove_ui_production.sh
            rm remove_ui_production.sh
        fi
        
        echo -e "${GREEN}✓ Bypasses applied${NC}"
        
        # Update .env to indicate bypasses are applied
        sed -i "s/BYPASSES_APPLIED=false/BYPASSES_APPLIED=true/" .env.production
    else
        echo -e "${YELLOW}Bypass scripts not found, skipping...${NC}"
    fi
fi

echo ""
echo -e "${BLUE}=== Service Status ===${NC}"
docker compose -f docker-compose.production.yml ps

echo ""
echo -e "${BLUE}=== Getting Server IP ===${NC}"
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "Server IP: $SERVER_IP"

echo ""
echo "========================================"
echo -e "${GREEN}DEPLOYMENT COMPLETE!${NC}"
echo "========================================"
echo ""
echo "Invoice Ninja is running!"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Configure Nginx Proxy Manager:"
echo "   - Add proxy host for your domain"
echo "   - Forward to: $SERVER_IP:9000"
echo "   - Use FastCGI configuration from NPM_CONFIGURATION.md"
echo ""
echo "2. Configure Firewall:"
echo "   sudo ufw allow from NPM_SERVER_IP to any port 9000"
echo "   sudo ufw deny 9000"
echo "   sudo ufw enable"
echo ""
echo "3. Test Connection:"
echo "   From NPM server: telnet $SERVER_IP 9000"
echo ""
echo "4. Access Invoice Ninja:"
echo "   https://your-configured-domain.com"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "View logs:    docker compose -f docker-compose.production.yml logs -f app"
echo "Stop:         docker compose -f docker-compose.production.yml down"
echo "Restart:      docker compose -f docker-compose.production.yml restart"
echo "Backup DB:    docker compose -f docker-compose.production.yml exec mysql mysqldump -u root -p ninja > backup.sql"
echo ""
echo -e "${YELLOW}Security Notes:${NC}"
echo "• PHP-FPM is exposed on port 9000 - configure firewall!"
echo "• Update passwords in .env.production"
echo "• Enable TRUSTED_PROXIES with specific IP"
echo "• Regular backups recommended"

if grep -q "BYPASSES_APPLIED=true" .env.production; then
    echo ""
    echo -e "${YELLOW}⚠ Security Bypasses Applied:${NC}"
    echo "• All premium features enabled"
    echo "• License checks disabled"
    echo "• For testing purposes only"
fi