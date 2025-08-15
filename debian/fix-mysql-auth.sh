#!/bin/bash

# Fix MySQL Authentication Issues
# This script resets the MySQL container and ensures proper user creation

set -e

echo "========================================="
echo "MySQL Authentication Fix Script"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  WARNING: This will reset your MySQL database!${NC}"
echo "All existing Invoice Ninja data will be lost."
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${BLUE}Step 1: Stopping containers...${NC}"
docker compose -f docker-compose.production.yml down

echo ""
echo -e "${BLUE}Step 2: Removing MySQL volume to ensure clean state...${NC}"
docker volume rm debian_mysql_data 2>/dev/null || true
echo "MySQL data volume removed"

echo ""
echo -e "${BLUE}Step 3: Creating fresh .env file from .env.production...${NC}"
cp .env.production .env
echo ".env file created from .env.production"

echo ""
echo -e "${BLUE}Step 4: Verifying environment variables...${NC}"
source .env.production

if [ -z "$MYSQL_ROOT_PASSWORD" ] || [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}Error: MySQL passwords not set in .env.production${NC}"
    exit 1
fi

echo "MySQL Root Password: [SET]"
echo "MySQL User Password: [SET]"
echo "MySQL Database: ${MYSQL_DATABASE:-ninja}"
echo "MySQL User: ${MYSQL_USER:-ninja}"

echo ""
echo -e "${BLUE}Step 5: Starting MySQL container only...${NC}"
docker compose -f docker-compose.production.yml up -d mysql

echo ""
echo -e "${BLUE}Step 6: Waiting for MySQL to initialize (this may take 30-60 seconds)...${NC}"
echo -n "Waiting"

# Wait longer for initial setup
for i in {1..60}; do
    if docker compose -f docker-compose.production.yml exec mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        echo "MySQL is ready!"
        break
    fi
    echo -n "."
    sleep 2
    
    if [ $i -eq 60 ]; then
        echo -e " ${RED}✗${NC}"
        echo "MySQL failed to start. Checking logs..."
        docker compose -f docker-compose.production.yml logs mysql | tail -20
        exit 1
    fi
done

echo ""
echo -e "${BLUE}Step 7: Verifying MySQL user creation...${NC}"

# Load environment variables
source .env.production

# Check if ninja user exists and has correct permissions
echo "Checking ninja user..."
docker compose -f docker-compose.production.yml exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
    SELECT User, Host FROM mysql.user WHERE User='ninja';
    SHOW GRANTS FOR 'ninja'@'%';
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User 'ninja' exists${NC}"
else
    echo -e "${YELLOW}Creating ninja user...${NC}"
    docker compose -f docker-compose.production.yml exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
        CREATE USER IF NOT EXISTS 'ninja'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        GRANT ALL PRIVILEGES ON ninja.* TO 'ninja'@'%';
        FLUSH PRIVILEGES;
    "
    echo -e "${GREEN}✓ User created${NC}"
fi

echo ""
echo -e "${BLUE}Step 8: Testing MySQL connection with ninja user...${NC}"
docker compose -f docker-compose.production.yml exec mysql mysql -u ninja -p${MYSQL_PASSWORD} -e "SELECT 'Connection successful!' as Status;" ninja

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ MySQL connection test successful${NC}"
else
    echo -e "${RED}✗ MySQL connection test failed${NC}"
    echo "Attempting to fix..."
    
    # Reset the password
    docker compose -f docker-compose.production.yml exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
        ALTER USER 'ninja'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        FLUSH PRIVILEGES;
    "
    
    # Test again
    docker compose -f docker-compose.production.yml exec mysql mysql -u ninja -p${MYSQL_PASSWORD} -e "SELECT 'Connection fixed!' as Status;" ninja
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ MySQL connection fixed${NC}"
    else
        echo -e "${RED}Failed to fix MySQL connection${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}Step 9: Starting Redis container...${NC}"
docker compose -f docker-compose.production.yml up -d redis

echo ""
echo -e "${BLUE}Step 10: Starting app container...${NC}"
docker compose -f docker-compose.production.yml up -d app

echo ""
echo -e "${BLUE}Step 11: Waiting for app to be ready...${NC}"
echo -n "Waiting for PHP-FPM"
for i in {1..30}; do
    if docker compose -f docker-compose.production.yml exec app pgrep -f "php-fpm: master process" &>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${BLUE}Step 12: Running database migrations...${NC}"
docker compose -f docker-compose.production.yml exec app php artisan migrate --force

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database migrations completed${NC}"
else
    echo -e "${YELLOW}Migration issues detected, attempting to fix...${NC}"
    docker compose -f docker-compose.production.yml exec app php artisan migrate:fresh --seed --force
fi

echo ""
echo -e "${BLUE}Step 13: Clearing application cache...${NC}"
docker compose -f docker-compose.production.yml exec app php artisan cache:clear
docker compose -f docker-compose.production.yml exec app php artisan config:clear
docker compose -f docker-compose.production.yml exec app php artisan view:clear

echo ""
echo -e "${BLUE}Step 14: Checking container status...${NC}"
docker compose -f docker-compose.production.yml ps

echo ""
echo -e "${BLUE}Step 15: Testing app database connection...${NC}"
docker compose -f docker-compose.production.yml exec app php artisan tinker --execute="echo 'Database connected: ' . (DB::connection()->getPdo() ? 'YES' : 'NO');"

echo ""
echo "========================================="
echo -e "${GREEN}MySQL AUTHENTICATION FIXED!${NC}"
echo "========================================="
echo ""
echo "All containers should now be running properly."
echo ""
echo "Next steps:"
echo "1. Apply bypasses if needed: ./apply_bypass_complete.sh"
echo "2. Configure Nginx Proxy Manager"
echo "3. Access Invoice Ninja at your configured domain"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "View logs:    docker compose -f docker-compose.production.yml logs -f"
echo "App logs:     docker compose -f docker-compose.production.yml logs -f app"
echo "MySQL logs:   docker compose -f docker-compose.production.yml logs -f mysql"
echo ""

# Show last few log lines to verify everything is working
echo -e "${BLUE}Recent app logs:${NC}"
docker compose -f docker-compose.production.yml logs app --tail=10