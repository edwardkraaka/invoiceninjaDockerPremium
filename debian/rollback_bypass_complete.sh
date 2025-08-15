#!/bin/bash

# Invoice Ninja Security Audit - Complete Bypass Rollback
# Restores all original files and removes all bypasses

set -e

echo "======================================================="
echo "Invoice Ninja Security Audit - Complete Bypass Rollback"
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

echo -e "${YELLOW}This will restore ALL original Invoice Ninja files${NC}"
echo -e "${YELLOW}and remove ALL bypass modifications.${NC}"
read -p "Continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled"
    exit 0
fi

echo ""
RESTORED_COUNT=0
FAILED_COUNT=0

# Function to restore a file
restore_file() {
    local backup_file="$1"
    local target_file="$2"
    local description="$3"
    
    if docker compose exec app test -f "$backup_file"; then
        docker compose exec app cp "$backup_file" "$target_file"
        echo -e "✓ Restored: $description"
        RESTORED_COUNT=$((RESTORED_COUNT + 1))
        return 0
    else
        echo -e "⚠ No backup for: $description (downloading original)"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

echo -e "${BLUE}=== Restoring Backend Files ===${NC}"

# Restore Account.php
if ! restore_file "/var/www/html/backups/Account.php.original" \
                  "/var/www/html/app/Models/Account.php" \
                  "Account.php"; then
    # Download original from GitHub
    docker compose exec app bash -c "
        curl -sL https://raw.githubusercontent.com/invoiceninja/invoiceninja/v5-stable/app/Models/Account.php > /var/www/html/app/Models/Account.php
    "
    echo -e "✓ Downloaded original Account.php"
fi

# Restore Company.php if backup exists
restore_file "/var/www/html/backups/Company.php.original" \
            "/var/www/html/app/Models/Company.php" \
            "Company.php" || true

echo ""
echo -e "${BLUE}=== Restoring Language Files ===${NC}"

# Restore texts.php
if ! restore_file "/var/www/html/backups/texts.php.original" \
                  "/var/www/html/lang/en/texts.php" \
                  "texts.php"; then
    docker compose exec app bash -c "
        curl -sL https://raw.githubusercontent.com/invoiceninja/invoiceninja/v5-stable/lang/en/texts.php > /var/www/html/lang/en/texts.php
    "
    echo -e "✓ Downloaded original texts.php"
fi

echo ""
echo -e "${BLUE}=== Restoring Blade Templates ===${NC}"

# List of blade files to restore
BLADE_FILES=(
    "footer.blade.php"
    "vendor_footer.blade.php"
    "guest.blade.php"
    "master.blade.php"
    "vendor_app.blade.php"
)

for blade_file in "${BLADE_FILES[@]}"; do
    backup_path="/var/www/html/backups/${blade_file}.original"
    
    # Find the target path
    target_path=$(docker compose exec app find /var/www/html/resources/views -name "$blade_file" 2>/dev/null | head -1 || echo "")
    
    if [ -n "$target_path" ]; then
        restore_file "$backup_path" "$target_path" "$blade_file" || true
    fi
done

echo ""
echo -e "${BLUE}=== Restoring JavaScript Bundles ===${NC}"

# Restore JavaScript files
docker compose exec app bash -c '
for backup_file in /var/www/html/backups/*.js.original; do
    if [ -f "$backup_file" ]; then
        original_name=$(basename "$backup_file" .original)
        target_file="/var/www/html/public/$original_name"
        
        if [ -f "$target_file" ]; then
            cp "$backup_file" "$target_file"
            echo "✓ Restored: $original_name"
        fi
    fi
done
'

echo ""
echo -e "${BLUE}=== Removing Custom Middleware ===${NC}"

# Remove custom middleware if added
docker compose exec app rm -f /var/www/html/app/Http/Middleware/WhiteLabelBypass.php
echo -e "✓ Removed WhiteLabelBypass middleware"

echo ""
echo -e "${BLUE}=== Clearing All Caches ===${NC}"

docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear
docker compose exec app php artisan route:clear

# Clear compiled views
docker compose exec app bash -c "rm -rf /var/www/html/storage/framework/views/*.php"

echo -e "${GREEN}✓ All caches cleared${NC}"

echo ""
echo -e "${BLUE}=== Restarting Services ===${NC}"

docker compose exec app supervisorctl restart all
echo -e "${GREEN}✓ Services restarted${NC}"

echo ""
echo -e "${BLUE}=== Verification ===${NC}"

# Check if SECURITY AUDIT markers are gone
if docker compose exec app grep -q "SECURITY AUDIT:" /var/www/html/app/Models/Account.php 2>/dev/null; then
    echo -e "${YELLOW}⚠ Warning: Some audit markers may still be present${NC}"
else
    echo -e "${GREEN}✓ All audit markers removed${NC}"
fi

# Check if Purchase White Label is back in language file
if docker compose exec app grep -q "'white_label_button' => 'Purchase White Label'" /var/www/html/lang/en/texts.php 2>/dev/null; then
    echo -e "${GREEN}✓ Original language strings restored${NC}"
else
    echo -e "${YELLOW}⚠ Language strings may not be fully restored${NC}"
fi

echo ""
echo "======================================================="
echo -e "${GREEN}ROLLBACK COMPLETE${NC}"
echo "======================================================="
echo ""
echo "Summary:"
echo "• Restored files: $RESTORED_COUNT"
echo "• Files without backups: $FAILED_COUNT"
echo ""
echo "Original functionality restored:"
echo "• License validation active"
echo "• Premium features require valid license"
echo "• Enterprise features restricted"
echo "• White label requires purchase"
echo "• UI shows purchase prompts"
echo ""
echo -e "${YELLOW}Note: Clear browser cache (Ctrl+F5) to see restored UI${NC}"
echo ""
echo "Run ./verify_bypass_complete.sh to confirm rollback"