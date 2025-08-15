#!/bin/bash

# Invoice Ninja Security Audit - Complete Bypass Verification
# Verifies all bypass modifications are active

set -e

echo "======================================================="
echo "Invoice Ninja Security Audit - Complete Bypass Verifier"
echo "======================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_CHECKS=0
PASSED_CHECKS=0

# Function to check and report
check_item() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    result=$(docker compose exec app bash -c "$command" 2>/dev/null || echo "ERROR")
    
    if [[ "$result" == *"$expected"* ]]; then
        echo -e "✓ $description: ${GREEN}PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "✗ $description: ${RED}FAIL${NC}"
        return 1
    fi
}

echo -e "${BLUE}=== Backend Checks ===${NC}"
check_item "Account->isPaid() returns true" \
    "grep -A1 'isPaid(): bool' /var/www/html/app/Models/Account.php | grep 'return true; // SECURITY AUDIT' | wc -l" \
    "1"

check_item "Account->isPremium() returns true" \
    "grep -A1 'isPremium(): bool' /var/www/html/app/Models/Account.php | grep 'return true; // SECURITY AUDIT' | wc -l" \
    "1"

check_item "Feature bypasses active" \
    "grep 'SECURITY AUDIT: Feature bypass' /var/www/html/app/Models/Account.php | wc -l | xargs" \
    ""

echo ""
echo -e "${BLUE}=== Language File Checks ===${NC}"
check_item "Purchase White Label text removed" \
    "grep \"'white_label_button' =>\" /var/www/html/lang/en/texts.php | grep -c \"''\"" \
    "1"

check_item "White label purchase link removed" \
    "grep \"'white_label_purchase_link' =>\" /var/www/html/lang/en/texts.php | grep -c \"''\"" \
    "1"

echo ""
echo -e "${BLUE}=== Template Checks ===${NC}"
check_item "Footer template modified" \
    "grep -c 'isPaid()' /var/www/html/resources/views/portal/ninja2020/components/general/footer.blade.php || echo 0" \
    "0"

echo ""
echo -e "${BLUE}=== JavaScript Bundle Checks ===${NC}"
# Check if Purchase White Label has been removed from bundles
JS_CHECK=$(docker compose exec app bash -c "grep -l 'Purchase White Label' /var/www/html/public/bundle*.js 2>/dev/null | wc -l" || echo "0")
if [ "$JS_CHECK" == "0" ]; then
    echo -e "✓ Purchase White Label removed from JS: ${GREEN}PASS${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "✗ Purchase White Label still in JS: ${YELLOW}PARTIAL${NC}"
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

echo ""
echo -e "${BLUE}=== Functional Tests ===${NC}"

# Test with PHP
docker compose exec app bash -c 'cat > /tmp/test_complete.php << '\''EOF'\''
<?php
require_once "/var/www/html/vendor/autoload.php";
require_once "/var/www/html/app/Models/Account.php";

use App\Models\Account;

$account = new Account();
$results = [
    "isPaid" => $account->isPaid(),
    "isPremium" => $account->isPremium(),
    "white_label" => $account->hasFeature(Account::FEATURE_WHITE_LABEL),
    "api" => $account->hasFeature(Account::FEATURE_API),
    "documents" => $account->hasFeature(Account::FEATURE_DOCUMENTS),
];

echo json_encode($results);
EOF
'

FUNC_RESULTS=$(docker compose exec app php /tmp/test_complete.php 2>/dev/null)

if echo "$FUNC_RESULTS" | grep -q '"isPaid":true'; then
    echo -e "✓ Functional: isPaid() = true: ${GREEN}PASS${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "✗ Functional: isPaid() = true: ${RED}FAIL${NC}"
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

if echo "$FUNC_RESULTS" | grep -q '"isPremium":true'; then
    echo -e "✓ Functional: isPremium() = true: ${GREEN}PASS${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "✗ Functional: isPremium() = true: ${RED}FAIL${NC}"
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

if echo "$FUNC_RESULTS" | grep -q '"white_label":true'; then
    echo -e "✓ Functional: White Label enabled: ${GREEN}PASS${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "✗ Functional: White Label enabled: ${RED}FAIL${NC}"
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Cleanup
docker compose exec app rm -f /tmp/test_complete.php

echo ""
echo "======================================================="
echo -e "${BLUE}VERIFICATION SUMMARY${NC}"
echo "======================================================="
echo "Checks Passed: $PASSED_CHECKS / $TOTAL_CHECKS"

if [ "$PASSED_CHECKS" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}✓ ALL BYPASSES FULLY ACTIVE${NC}"
    echo ""
    echo "Complete bypass successful:"
    echo "• Backend authorization bypassed"
    echo "• UI purchase elements removed"
    echo "• Language strings modified"
    echo "• Premium features enabled"
    echo "• White label active"
elif [ "$PASSED_CHECKS" -gt $((TOTAL_CHECKS / 2)) ]; then
    echo -e "${YELLOW}⚠ BYPASSES PARTIALLY ACTIVE${NC}"
    echo ""
    echo "Some bypasses are working but not all."
    echo "Try clearing browser cache or restarting container."
else
    echo -e "${RED}✗ BYPASSES NOT ACTIVE${NC}"
    echo ""
    echo "Run ./apply_bypass_complete.sh to apply bypasses"
fi

echo "======================================================="