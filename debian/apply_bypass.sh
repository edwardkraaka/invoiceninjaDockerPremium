#!/bin/bash

# Invoice Ninja Security Audit - Paywall Bypass Script
# This script applies bypasses to test security implications
# FOR AUTHORIZED PENETRATION TESTING ONLY

set -e

echo "================================================"
echo "Invoice Ninja Security Audit - Bypass Applicator"
echo "FOR AUTHORIZED PENETRATION TESTING ONLY"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running from correct directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found!${NC}"
    echo "Please run this script from the dockerfiles/debian directory"
    exit 1
fi

# Check if container is running
if ! docker compose ps | grep -q "app.*Up"; then
    echo -e "${RED}Error: App container is not running!${NC}"
    echo "Please start the containers first: docker compose up -d"
    exit 1
fi

echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# Create backup of original file
echo "Creating backup of original Account.php..."
docker compose exec app bash -c "cp /var/www/html/app/Models/Account.php /var/www/html/app/Models/Account.php.original 2>/dev/null || true"

echo "Applying paywall bypasses..."
echo ""

# Apply the bypasses using sed commands
docker compose exec app bash -c '
# Modify isPaid() method
sed -i "/public function isPaid(): bool/,/^    }/{
    /return.*Ninja::isNinja/c\
        return true; // SECURITY AUDIT: Bypass white label check
}" /var/www/html/app/Models/Account.php

# Modify isPremium() method  
sed -i "/public function isPremium(): bool/,/^    }/{
    /return.*Ninja::isHosted/c\
        return true; // SECURITY AUDIT: Enable all premium features
}" /var/www/html/app/Models/Account.php

# Modify hasFeature() method for various features
sed -i "/case self::FEATURE_WHITE_LABEL:/,/case .*:/{
    /return.*!empty.*plan_details/c\
                return true; // SECURITY AUDIT: Bypass white label feature check
}" /var/www/html/app/Models/Account.php

sed -i "/case self::FEATURE_REMOVE_CREATED_BY:/,/case .*:/{
    /return.*!empty.*plan_details/c\
                return true; // SECURITY AUDIT: Remove created by check
}" /var/www/html/app/Models/Account.php

sed -i "/case self::FEATURE_MORE_CLIENTS:/,/case .*:/{
    /return.*self_host.*plan_details/c\
                return true; // SECURITY AUDIT: Enable unlimited clients
}" /var/www/html/app/Models/Account.php

sed -i "/case self::FEATURE_USERS:/,/case .*:/{
    /return.*self_host.*PLAN_ENTERPRISE/c\
                return true; // SECURITY AUDIT: Enable multiple users
}" /var/www/html/app/Models/Account.php

sed -i "/case self::FEATURE_DOCUMENTS:/,/case .*:/{
    /return.*self_host.*PLAN_ENTERPRISE/c\
                return true; // SECURITY AUDIT: Enable documents feature
}" /var/www/html/app/Models/Account.php

sed -i "/case self::FEATURE_USER_PERMISSIONS:/,/case .*:/{
    /return.*self_host.*PLAN_ENTERPRISE/c\
                return true; // SECURITY AUDIT: Enable user permissions
}" /var/www/html/app/Models/Account.php

# Also bypass other premium features
sed -i "/case self::FEATURE_API:/,/case .*:/{
    /return.*self_host.*plan_details/c\
                return true; // SECURITY AUDIT: Enable API access
}" /var/www/html/app/Models/Account.php

sed -i "/case self::FEATURE_REPORTS:/,/case .*:/{
    /return.*self_host.*plan_details/c\
                return true; // SECURITY AUDIT: Enable reports
}" /var/www/html/app/Models/Account.php
'

echo -e "${GREEN}✓ Bypasses applied${NC}"
echo ""

# Clear Laravel cache
echo "Clearing Laravel cache..."
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear

echo -e "${GREEN}✓ Cache cleared${NC}"
echo ""

# Restart PHP-FPM to ensure changes take effect
echo "Restarting PHP-FPM..."
docker compose exec app supervisorctl restart php-fpm

echo -e "${GREEN}✓ PHP-FPM restarted${NC}"
echo ""

echo "================================================"
echo -e "${GREEN}BYPASS APPLICATION COMPLETE${NC}"
echo "================================================"
echo ""
echo "Security implications to test:"
echo "1. White label branding removed from PDFs"
echo "2. All premium features enabled without license"
echo "3. Enterprise features (multi-user, documents) enabled"
echo "4. API access enabled without restrictions"
echo "5. Unlimited client accounts"
echo ""
echo -e "${YELLOW}Remember to document these findings in your penetration test report${NC}"
echo ""
echo "To verify bypasses: ./verify_bypass.sh"
echo "To rollback changes: ./rollback_bypass.sh"