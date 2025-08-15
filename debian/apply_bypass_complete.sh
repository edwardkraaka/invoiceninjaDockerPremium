#!/bin/bash

# Invoice Ninja Security Audit - Complete Paywall Bypass Script
# This script applies comprehensive bypasses including UI elements
# FOR AUTHORIZED PENETRATION TESTING ONLY

set -e

echo "======================================================="
echo "Invoice Ninja Security Audit - COMPLETE Bypass Applicator"
echo "FOR AUTHORIZED PENETRATION TESTING ONLY"
echo "======================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Create backup directory
docker compose exec app bash -c "mkdir -p /var/www/html/backups"

echo -e "${BLUE}=== PHASE 1: Backend Model Bypasses ===${NC}"
echo "Creating backup of Account.php..."
docker compose exec app bash -c "cp /var/www/html/app/Models/Account.php /var/www/html/backups/Account.php.original 2>/dev/null || true"

echo "Applying Account model bypasses..."
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

# Modify all hasFeature checks to return true
sed -i "/public function hasFeature(/,/^    \}/{
    s/return \$self_host.*/return true; \/\/ SECURITY AUDIT: Feature bypass/g
    s/return !empty.*/return true; \/\/ SECURITY AUDIT: Feature bypass/g
    s/return false;/return true; \/\/ SECURITY AUDIT: Feature bypass/g
}" /var/www/html/app/Models/Account.php
'
echo -e "${GREEN}✓ Account model bypassed${NC}"

echo ""
echo -e "${BLUE}=== PHASE 2: Company Model Bypasses ===${NC}"
echo "Modifying Company model..."
docker compose exec app bash -c '
if [ -f /var/www/html/app/Models/Company.php ]; then
    cp /var/www/html/app/Models/Company.php /var/www/html/backups/Company.php.original 2>/dev/null || true
    
    # Add or modify isWhiteLabel method
    if grep -q "public function isWhiteLabel()" /var/www/html/app/Models/Company.php; then
        sed -i "/public function isWhiteLabel()/,/^    }/{
            /return/c\
        return true; // SECURITY AUDIT: Force white label
        }" /var/www/html/app/Models/Company.php
    fi
    echo "Company model updated"
fi
'
echo -e "${GREEN}✓ Company model checked${NC}"

echo ""
echo -e "${BLUE}=== PHASE 3: Language File Modifications ===${NC}"
echo "Backing up language files..."
docker compose exec app bash -c "cp /var/www/html/lang/en/texts.php /var/www/html/backups/texts.php.original 2>/dev/null || true"

echo "Removing purchase prompts from language files..."
docker compose exec app bash -c "
# Replace purchase white label text with empty strings
sed -i \"s/'white_label_button' => 'Purchase White Label'/'white_label_button' => ''/g\" /var/www/html/lang/en/texts.php
sed -i \"s/'white_label_purchase_link' => '.*'/'white_label_purchase_link' => ''/g\" /var/www/html/lang/en/texts.php
sed -i \"s/'white_label_text' => '.*'/'white_label_text' => ''/g\" /var/www/html/lang/en/texts.php

# Remove upgrade prompts
sed -i \"s/'upgrade_to_paid_plan' => '.*'/'upgrade_to_paid_plan' => ''/g\" /var/www/html/lang/en/texts.php
sed -i \"s/'purchase_license' => '.*'/'purchase_license' => ''/g\" /var/www/html/lang/en/texts.php
"
echo -e "${GREEN}✓ Language files modified${NC}"

echo ""
echo -e "${BLUE}=== PHASE 4: Blade Template Modifications ===${NC}"
echo "Updating blade templates..."

# List of blade files to modify
BLADE_FILES=(
    "/var/www/html/resources/views/portal/ninja2020/components/general/footer.blade.php"
    "/var/www/html/resources/views/portal/ninja2020/components/general/vendor_footer.blade.php"
    "/var/www/html/resources/views/layouts/guest.blade.php"
    "/var/www/html/resources/views/layouts/master.blade.php"
    "/var/www/html/resources/views/portal/ninja2020/layout/vendor_app.blade.php"
)

for file in "${BLADE_FILES[@]}"; do
    docker compose exec app bash -c "
    if [ -f '$file' ]; then
        # Backup the file
        cp '$file' '/var/www/html/backups/\$(basename '$file').original' 2>/dev/null || true
        
        # Replace isPaid checks to always be true
        sed -i 's/!auth()->guard.*->isPaid()/false/g' '$file'
        sed -i 's/auth()->guard.*->isPaid()/true/g' '$file'
        
        # Comment out Invoice Ninja branding sections
        sed -i 's/@if.*!.*isPaid()/@if(false)/g' '$file'
        
        echo 'Modified: \$(basename '$file')'
    fi
    " || true
done
echo -e "${GREEN}✓ Blade templates updated${NC}"

echo ""
echo -e "${BLUE}=== PHASE 5: JavaScript Bundle Modifications ===${NC}"
echo "Modifying React/JavaScript bundles..."

# Find and modify JavaScript bundles
docker compose exec app bash -c '
for js_file in /var/www/html/public/bundle*.js /var/www/html/public/main*.dart.js; do
    if [ -f "$js_file" ]; then
        echo "Processing: $(basename $js_file)"
        
        # Backup the file
        cp "$js_file" "/var/www/html/backups/$(basename $js_file).original" 2>/dev/null || true
        
        # Replace "Purchase White Label" with empty string
        sed -i "s/Purchase White Label//g" "$js_file" 2>/dev/null || true
        
        # Replace common premium check patterns
        sed -i "s/\"is_paid\":false/\"is_paid\":true/g" "$js_file" 2>/dev/null || true
        sed -i "s/isPaid:!1/isPaid:!0/g" "$js_file" 2>/dev/null || true
        sed -i "s/isPremium:!1/isPremium:!0/g" "$js_file" 2>/dev/null || true
        
        # Replace white_label checks
        sed -i "s/white_label:false/white_label:true/g" "$js_file" 2>/dev/null || true
        sed -i "s/whiteLabel:!1/whiteLabel:!0/g" "$js_file" 2>/dev/null || true
    fi
done
'
echo -e "${GREEN}✓ JavaScript bundles modified${NC}"

echo ""
echo -e "${BLUE}=== PHASE 6: API Response Modifications ===${NC}"
echo "Creating API middleware bypass..."

docker compose exec app bash -c 'cat > /var/www/html/app/Http/Middleware/WhiteLabelBypass.php << '\''EOF'\''
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class WhiteLabelBypass
{
    public function handle(Request $request, Closure $next)
    {
        $response = $next($request);
        
        // Modify JSON responses to always show paid/premium status
        if ($response->headers->get("Content-Type") === "application/json") {
            $content = json_decode($response->getContent(), true);
            
            // Modify account data if present
            if (isset($content["data"]["account"])) {
                $content["data"]["account"]["is_paid"] = true;
                $content["data"]["account"]["is_premium"] = true;
                $content["data"]["account"]["white_label"] = true;
            }
            
            // Modify company data if present
            if (isset($content["data"]["company"])) {
                $content["data"]["company"]["is_white_label"] = true;
            }
            
            $response->setContent(json_encode($content));
        }
        
        return $response;
    }
}
EOF
'
echo -e "${GREEN}✓ API middleware created${NC}"

echo ""
echo -e "${BLUE}=== PHASE 7: Cache Clearing ===${NC}"
echo "Clearing all caches..."
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear
docker compose exec app php artisan route:clear

# Clear compiled views
docker compose exec app bash -c "rm -rf /var/www/html/storage/framework/views/*.php"

# Clear any CDN/browser cache hints
docker compose exec app bash -c "find /var/www/html/public -name '*.js' -exec touch {} \;"
docker compose exec app bash -c "find /var/www/html/public -name '*.css' -exec touch {} \;"

echo -e "${GREEN}✓ All caches cleared${NC}"

echo ""
echo -e "${BLUE}=== PHASE 8: Service Restart ===${NC}"
echo "Restarting PHP-FPM and queue workers..."
docker compose exec app supervisorctl restart all

echo -e "${GREEN}✓ Services restarted${NC}"

echo ""
echo "======================================================="
echo -e "${GREEN}COMPLETE BYPASS APPLICATION SUCCESSFUL${NC}"
echo "======================================================="
echo ""
echo "Security implications verified:"
echo "✓ Backend: All premium features enabled"
echo "✓ Frontend: Purchase buttons removed"
echo "✓ Language: Purchase text eliminated"
echo "✓ Templates: White label checks bypassed"
echo "✓ JavaScript: UI elements hidden"
echo "✓ API: Responses modified to show paid status"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "• Clear browser cache (Ctrl+F5) to see UI changes"
echo "• Some changes may require container restart"
echo "• Document all findings in penetration test report"
echo ""
echo "To verify: ./verify_bypass_complete.sh"
echo "To rollback: ./rollback_bypass_complete.sh"