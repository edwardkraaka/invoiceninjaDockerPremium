#!/bin/bash

# Invoice Ninja Security Audit - Bypass Rollback Script
# This script removes bypasses and restores original functionality

set -e

echo "================================================"
echo "Invoice Ninja Security Audit - Bypass Rollback"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if container is running
if ! docker compose ps | grep -q "app.*Up"; then
    echo -e "${RED}Error: App container is not running!${NC}"
    exit 1
fi

echo -e "${YELLOW}This will restore the original Invoice Ninja files${NC}"
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled"
    exit 0
fi

echo ""
echo "Checking for backup file..."

# Check if backup exists
if docker compose exec app test -f /var/www/html/app/Models/Account.php.original; then
    echo -e "${GREEN}✓ Backup file found${NC}"
    echo ""
    
    echo "Restoring original Account.php..."
    docker compose exec app bash -c "cp /var/www/html/app/Models/Account.php.original /var/www/html/app/Models/Account.php"
    
    echo -e "${GREEN}✓ Original file restored${NC}"
else
    echo -e "${YELLOW}⚠ No backup file found${NC}"
    echo "Attempting to restore from Invoice Ninja source..."
    
    # Download original file from Invoice Ninja repository
    docker compose exec app bash -c "
        curl -sL https://raw.githubusercontent.com/invoiceninja/invoiceninja/v5-stable/app/Models/Account.php > /tmp/Account.php.original &&
        cp /tmp/Account.php.original /var/www/html/app/Models/Account.php &&
        rm /tmp/Account.php.original
    "
    
    echo -e "${GREEN}✓ Original file downloaded and restored${NC}"
fi

echo ""

# Clear Laravel cache
echo "Clearing Laravel cache..."
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear  
docker compose exec app php artisan view:clear

echo -e "${GREEN}✓ Cache cleared${NC}"
echo ""

# Restart PHP-FPM
echo "Restarting PHP-FPM..."
docker compose exec app supervisorctl restart php-fpm

echo -e "${GREEN}✓ PHP-FPM restarted${NC}"
echo ""

# Verify rollback
echo "Verifying rollback..."
if docker compose exec app grep -q "SECURITY AUDIT:" /var/www/html/app/Models/Account.php 2>/dev/null; then
    echo -e "${RED}✗ Audit markers still present - rollback may have failed${NC}"
else
    echo -e "${GREEN}✓ Audit markers removed - rollback successful${NC}"
fi

echo ""
echo "================================================"
echo -e "${GREEN}ROLLBACK COMPLETE${NC}"
echo "================================================"
echo ""
echo "Original functionality restored:"
echo "• License validation active"
echo "• Premium features require valid license"
echo "• Enterprise features restricted"
echo "• White label branding in place"
echo ""
echo "Run ./verify_bypass.sh to confirm rollback"