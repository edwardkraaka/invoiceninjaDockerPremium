#!/bin/bash

# Quick MySQL Reset - Preserve data if possible
# This script tries to fix authentication without losing data

set -e

echo "========================================="
echo "Quick MySQL Authentication Reset"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
source .env.production

echo -e "${BLUE}Attempting to fix MySQL authentication...${NC}"
echo ""

# First, ensure .env exists
if [ ! -f .env ]; then
    echo "Creating .env from .env.production..."
    cp .env.production .env
fi

echo -e "${BLUE}Step 1: Connecting to MySQL as root...${NC}"
docker compose -f docker-compose.production.yml exec mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
    -- Drop and recreate the ninja user
    DROP USER IF EXISTS 'ninja'@'%';
    DROP USER IF EXISTS 'ninja'@'localhost';
    
    -- Create user with all possible host patterns
    CREATE USER 'ninja'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    CREATE USER 'ninja'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
    
    -- Grant all privileges
    GRANT ALL PRIVILEGES ON *.* TO 'ninja'@'%' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON *.* TO 'ninja'@'localhost' WITH GRANT OPTION;
    
    -- Ensure ninja database exists
    CREATE DATABASE IF NOT EXISTS ninja;
    
    -- Flush privileges
    FLUSH PRIVILEGES;
    
    -- Show the created users
    SELECT User, Host FROM mysql.user WHERE User='ninja';
" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ MySQL user reset successful${NC}"
else
    echo -e "${RED}Failed to reset MySQL user${NC}"
    echo "You may need to run the full reset script: ./fix-mysql-auth.sh"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Testing connection...${NC}"
docker compose -f docker-compose.production.yml exec mysql mysql -u ninja -p${MYSQL_PASSWORD} -e "SELECT 'Connection successful!' as Status;" ninja

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Connection test successful${NC}"
else
    echo -e "${RED}Connection test failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Restarting app container...${NC}"
docker compose -f docker-compose.production.yml restart app

echo ""
echo -e "${BLUE}Step 4: Waiting for app to be ready...${NC}"
sleep 10

echo ""
echo -e "${BLUE}Step 5: Checking container status...${NC}"
docker compose -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}MySQL authentication should now be fixed!${NC}"
echo ""
echo "Check app logs: docker compose -f docker-compose.production.yml logs -f app"