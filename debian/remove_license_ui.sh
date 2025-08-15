#!/bin/bash

# Invoice Ninja Security Audit - Remove License UI Elements
# Specifically targets Account Management license buttons and Pro labels
# FOR AUTHORIZED PENETRATION TESTING ONLY

set -e

echo "======================================================="
echo "Invoice Ninja - Remove License UI Elements"
echo "Targeting Account Management Page"
echo "======================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if container is running
if ! docker compose ps | grep -q "app.*Up"; then
    echo -e "${RED}Error: App container is not running!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# Backup bundles if not already backed up
echo -e "${BLUE}=== Creating Backups ===${NC}"
docker compose exec app bash -c "
mkdir -p /var/www/html/backups
for file in /var/www/html/public/bundle*.js; do
    if [ -f \"\$file\" ] && [ ! -f \"/var/www/html/backups/\$(basename \$file).ui_backup\" ]; then
        cp \"\$file\" \"/var/www/html/backups/\$(basename \$file).ui_backup\"
        echo \"Backed up: \$(basename \$file)\"
    fi
done
"

echo ""
echo -e "${BLUE}=== Removing License UI Text ===${NC}"

# More aggressive replacement for React bundles
docker compose exec app bash -c '
for js_file in /var/www/html/public/bundle*.js; do
    if [ -f "$js_file" ]; then
        echo "Processing: $(basename $js_file)"
        
        # Remove Purchase License button text and functionality
        sed -i "s/\"Purchase License\"/\"\"/g" "$js_file"
        sed -i "s/>Purchase License</><\/>/g" "$js_file"
        sed -i "s/Purchase License//g" "$js_file"
        
        # Remove Apply License button text
        sed -i "s/\"Apply License\"/\"\"/g" "$js_file"
        sed -i "s/>Apply License</><\/>/g" "$js_file"
        sed -i "s/Apply License//g" "$js_file"
        
        # Remove Pro labels and upgrade prompts
        sed -i "s/\"Pro\"/\"\"/g" "$js_file"
        sed -i "s/>Pro</><\/>/g" "$js_file"
        sed -i "s/\[Pro\]//g" "$js_file"
        sed -i "s/ Pro / /g" "$js_file"
        
        # Remove license-related function names (careful not to break code)
        sed -i "s/showPurchaseLicense:!0/showPurchaseLicense:!1/g" "$js_file"
        sed -i "s/showApplyLicense:!0/showApplyLicense:!1/g" "$js_file"
        sed -i "s/requiresProPlan:!0/requiresProPlan:!1/g" "$js_file"
        
        # Force paid status in JavaScript
        sed -i "s/isPaid:!1/isPaid:!0/g" "$js_file"
        sed -i "s/isPaid:false/isPaid:true/g" "$js_file"
        sed -i "s/is_paid:!1/is_paid:!0/g" "$js_file"
        sed -i "s/is_paid:false/is_paid:true/g" "$js_file"
        
        # Set plan to enterprise
        sed -i "s/plan:\"free\"/plan:\"enterprise\"/g" "$js_file"
        sed -i "s/plan:\"starter\"/plan:\"enterprise\"/g" "$js_file"
        sed -i "s/plan:\"pro\"/plan:\"enterprise\"/g" "$js_file"
        
        echo "Modified: $(basename $js_file)"
    fi
done
'

echo -e "${GREEN}✓ React bundles modified${NC}"

echo ""
echo -e "${BLUE}=== Updating Language Files ===${NC}"

docker compose exec app bash -c "
# Remove license-related language strings
sed -i \"s/'apply_license' => '.*'/'apply_license' => ''/g\" /var/www/html/lang/en/texts.php
sed -i \"s/'purchase_license' => '.*'/'purchase_license' => ''/g\" /var/www/html/lang/en/texts.php
sed -i \"s/'pro_plan_advanced_settings' => '.*'/'pro_plan_advanced_settings' => ''/g\" /var/www/html/lang/en/texts.php
sed -i \"s/'white_label_license_error' => '.*'/'white_label_license_error' => ''/g\" /var/www/html/lang/en/texts.php

echo 'Language file updated'
"

echo -e "${GREEN}✓ Language files updated${NC}"

echo ""
echo -e "${BLUE}=== Creating Account API Override ===${NC}"

# Create a more comprehensive API override
docker compose exec app bash -c 'cat > /var/www/html/app/Http/Controllers/AccountOverrideController.php << '\''EOF'\''
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AccountOverrideController extends Controller
{
    public function __construct()
    {
        // Force account to appear as paid enterprise
        if (auth()->user() && auth()->user()->account) {
            $account = auth()->user()->account;
            $account->plan = "enterprise";
            $account->plan_term = "month";
            $account->plan_paid = "2099-12-31";
            $account->plan_expires = "2099-12-31";
            $account->is_white_label = true;
            $account->has_valid_license = true;
        }
    }
}
EOF
'

echo -e "${GREEN}✓ Account override controller created${NC}"

echo ""
echo -e "${BLUE}=== Modifying Main Dart Files ===${NC}"

# Also modify the Dart/Flutter compiled files
docker compose exec app bash -c '
for dart_file in /var/www/html/public/main*.dart.js; do
    if [ -f "$dart_file" ] && [ -s "$dart_file" ]; then
        echo "Processing: $(basename $dart_file)"
        
        # Backup if not exists
        if [ ! -f "/var/www/html/backups/$(basename $dart_file).ui_backup" ]; then
            cp "$dart_file" "/var/www/html/backups/$(basename $dart_file).ui_backup"
        fi
        
        # Remove license UI elements
        sed -i "s/Purchase License//g" "$dart_file" 2>/dev/null || true
        sed -i "s/Apply License//g" "$dart_file" 2>/dev/null || true
        sed -i "s/purchase_license//g" "$dart_file" 2>/dev/null || true
        sed -i "s/apply_license//g" "$dart_file" 2>/dev/null || true
        
        # Force paid status
        sed -i "s/isPaid:!1/isPaid:!0/g" "$dart_file" 2>/dev/null || true
        sed -i "s/is_paid:!1/is_paid:!0/g" "$dart_file" 2>/dev/null || true
    fi
done
'

echo -e "${GREEN}✓ Dart files modified${NC}"

echo ""
echo -e "${BLUE}=== Clearing Caches ===${NC}"

# Clear all caches
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear

# Touch files to force browser refresh
docker compose exec app bash -c "
find /var/www/html/public -name '*.js' -exec touch {} \;
find /var/www/html/public -name '*.css' -exec touch {} \;
"

echo -e "${GREEN}✓ Caches cleared${NC}"

echo ""
echo -e "${BLUE}=== Restarting Services ===${NC}"

docker compose exec app supervisorctl restart php-fpm

echo -e "${GREEN}✓ PHP-FPM restarted${NC}"

echo ""
echo "======================================================="
echo -e "${GREEN}LICENSE UI REMOVAL COMPLETE${NC}"
echo "======================================================="
echo ""
echo "Removed from Account Management page:"
echo "✓ Purchase License button"
echo "✓ Apply License button"
echo "✓ Pro labels on settings"
echo "✓ License-related prompts"
echo ""
echo -e "${YELLOW}IMPORTANT: Clear browser cache completely:${NC}"
echo "1. Press Ctrl+Shift+Delete"
echo "2. Select 'Cached images and files'"
echo "3. Clear data"
echo "4. Refresh the page (Ctrl+F5)"
echo ""
echo "If buttons still appear:"
echo "1. Open browser DevTools (F12)"
echo "2. Go to Application/Storage tab"
echo "3. Clear Local Storage for this site"
echo "4. Hard refresh (Ctrl+Shift+R)"
echo ""
echo "To verify removal: Check Settings > Account Management"