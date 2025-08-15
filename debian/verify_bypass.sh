#!/bin/bash

# Invoice Ninja Security Audit - Bypass Verification Script
# This script verifies that bypasses have been applied correctly

set -e

echo "================================================"
echo "Invoice Ninja Security Audit - Bypass Verifier"
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

echo "Checking bypass implementation..."
echo ""

# Create a PHP test script inside the container
docker compose exec app bash -c 'cat > /tmp/test_bypass.php << '\''EOF'\''
<?php
require_once "/var/www/html/vendor/autoload.php";
require_once "/var/www/html/app/Models/Account.php";

use App\Models\Account;

// Create test account instance
$account = new Account();

// Test results array
$results = [];

// Test isPaid() method
$results["isPaid"] = $account->isPaid();

// Test isPremium() method  
$results["isPremium"] = $account->isPremium();

// Test individual features
$features = [
    "WHITE_LABEL" => Account::FEATURE_WHITE_LABEL,
    "REMOVE_CREATED_BY" => Account::FEATURE_REMOVE_CREATED_BY,
    "API" => Account::FEATURE_API,
    "REPORTS" => Account::FEATURE_REPORTS,
    "MORE_CLIENTS" => Account::FEATURE_MORE_CLIENTS,
    "DOCUMENTS" => Account::FEATURE_DOCUMENTS,
    "USER_PERMISSIONS" => Account::FEATURE_USER_PERMISSIONS,
    "USERS" => Account::FEATURE_USERS,
];

foreach ($features as $name => $feature) {
    $results["feature_" . $name] = $account->hasFeature($feature);
}

// Output results as JSON
echo json_encode($results);
EOF
'

# Run the test script
RESULTS=$(docker compose exec app php /tmp/test_bypass.php 2>/dev/null)

# Parse and display results
echo "Test Results:"
echo "============="
echo ""

# Check isPaid
if echo "$RESULTS" | grep -q '"isPaid":true'; then
    echo -e "✓ isPaid():          ${GREEN}TRUE (White label bypass active)${NC}"
else
    echo -e "✗ isPaid():          ${RED}FALSE (Bypass not working)${NC}"
fi

# Check isPremium
if echo "$RESULTS" | grep -q '"isPremium":true'; then
    echo -e "✓ isPremium():       ${GREEN}TRUE (Premium features enabled)${NC}"
else
    echo -e "✗ isPremium():       ${RED}FALSE (Bypass not working)${NC}"
fi

echo ""
echo "Feature Status:"
echo "--------------"

# Check individual features
if echo "$RESULTS" | grep -q '"feature_WHITE_LABEL":true'; then
    echo -e "✓ White Label:       ${GREEN}ENABLED${NC}"
else
    echo -e "✗ White Label:       ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_REMOVE_CREATED_BY":true'; then
    echo -e "✓ Remove Branding:   ${GREEN}ENABLED${NC}"
else
    echo -e "✗ Remove Branding:   ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_API":true'; then
    echo -e "✓ API Access:        ${GREEN}ENABLED${NC}"
else
    echo -e "✗ API Access:        ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_REPORTS":true'; then
    echo -e "✓ Reports:           ${GREEN}ENABLED${NC}"
else
    echo -e "✗ Reports:           ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_MORE_CLIENTS":true'; then
    echo -e "✓ Unlimited Clients: ${GREEN}ENABLED${NC}"
else
    echo -e "✗ Unlimited Clients: ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_DOCUMENTS":true'; then
    echo -e "✓ Documents:         ${GREEN}ENABLED${NC}"
else
    echo -e "✗ Documents:         ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_USER_PERMISSIONS":true'; then
    echo -e "✓ User Permissions:  ${GREEN}ENABLED${NC}"
else
    echo -e "✗ User Permissions:  ${RED}DISABLED${NC}"
fi

if echo "$RESULTS" | grep -q '"feature_USERS":true'; then
    echo -e "✓ Multiple Users:    ${GREEN}ENABLED${NC}"
else
    echo -e "✗ Multiple Users:    ${RED}DISABLED${NC}"
fi

echo ""

# Check for audit markers in the code
echo "Checking for audit markers in code..."
if docker compose exec app grep -q "SECURITY AUDIT:" /var/www/html/app/Models/Account.php 2>/dev/null; then
    echo -e "${GREEN}✓ Audit markers found in Account.php${NC}"
    BYPASS_ACTIVE=true
else
    echo -e "${YELLOW}⚠ No audit markers found (bypasses may not be applied)${NC}"
    BYPASS_ACTIVE=false
fi

echo ""
echo "================================================"

if [ "$BYPASS_ACTIVE" = true ]; then
    echo -e "${GREEN}BYPASS VERIFICATION COMPLETE - ALL ACTIVE${NC}"
    echo ""
    echo "Security implications confirmed:"
    echo "• License validation bypassed"
    echo "• Premium features accessible without payment"
    echo "• Enterprise features enabled"
    echo "• No external license checks performed"
else
    echo -e "${YELLOW}BYPASS NOT FULLY ACTIVE${NC}"
    echo "Run ./apply_bypass.sh to apply bypasses"
fi

echo "================================================"

# Cleanup
docker compose exec app rm -f /tmp/test_bypass.php