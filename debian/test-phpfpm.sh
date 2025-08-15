#!/bin/bash

# Test PHP-FPM Connection
# Run this after deployment to verify PHP-FPM is accessible

echo "================================"
echo "PHP-FPM Connection Test"
echo "================================"
echo ""

# Check if production compose file exists
if [ ! -f docker-compose.production.yml ]; then
    echo "Error: docker-compose.production.yml not found!"
    exit 1
fi

# Check if container is running
if ! docker compose -f docker-compose.production.yml ps | grep -q "app.*Up"; then
    echo "Error: App container is not running!"
    echo "Run: ./deploy-production.sh first"
    exit 1
fi

echo "✓ App container is running"
echo ""

# Get container IP and port binding
echo "Checking port binding..."
PORT_BINDING=$(docker compose -f docker-compose.production.yml port app 9000 2>/dev/null)
if [ -n "$PORT_BINDING" ]; then
    echo "✓ PHP-FPM accessible on: $PORT_BINDING"
else
    echo "✗ PHP-FPM port 9000 not exposed"
    exit 1
fi

echo ""
echo "Creating test PHP file..."
docker compose -f docker-compose.production.yml exec app bash -c "
    echo '<?php
    header(\"Content-Type: text/plain\");
    echo \"PHP-FPM Status: WORKING\\n\";
    echo \"PHP Version: \" . PHP_VERSION . \"\\n\";
    echo \"Server: \" . \\\$_SERVER[\"SERVER_SOFTWARE\"] . \"\\n\";
    echo \"Document Root: \" . \\\$_SERVER[\"DOCUMENT_ROOT\"] . \"\\n\";
    echo \"Script Name: \" . \\\$_SERVER[\"SCRIPT_NAME\"] . \"\\n\";
    echo \"\\nHTTPS Detection:\\n\";
    echo \"HTTPS: \" . (\\\$_SERVER[\"HTTPS\"] ?? \"not set\") . \"\\n\";
    echo \"HTTP_X_FORWARDED_PROTO: \" . (\\\$_SERVER[\"HTTP_X_FORWARDED_PROTO\"] ?? \"not set\") . \"\\n\";
    echo \"\\nProxy Headers:\\n\";
    echo \"HTTP_X_REAL_IP: \" . (\\\$_SERVER[\"HTTP_X_REAL_IP\"] ?? \"not set\") . \"\\n\";
    echo \"HTTP_X_FORWARDED_FOR: \" . (\\\$_SERVER[\"HTTP_X_FORWARDED_FOR\"] ?? \"not set\") . \"\\n\";
    echo \"REMOTE_ADDR: \" . \\\$_SERVER[\"REMOTE_ADDR\"] . \"\\n\";
    ?>' > /var/www/html/public/test-fpm.php
"

echo "✓ Test file created: /var/www/html/public/test-fpm.php"
echo ""

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "================================"
echo "CONNECTION INFORMATION"
echo "================================"
echo ""
echo "PHP-FPM Endpoint: $SERVER_IP:9000"
echo "Test file path: /var/www/html/public/test-fpm.php"
echo ""
echo "To test from Nginx Proxy Manager:"
echo "1. Configure FastCGI pass to: $SERVER_IP:9000"
echo "2. Visit: https://yourdomain.com/test-fpm.php"
echo ""
echo "FastCGI test with curl (from NPM server):"
echo "curl -v http://$SERVER_IP:9000/test-fpm.php"
echo ""
echo "Note: Direct HTTP requests to port 9000 won't work."
echo "PHP-FPM requires FastCGI protocol (through NPM)."
echo ""
echo "After testing, remove test file:"
echo "docker compose -f docker-compose.production.yml exec app rm /var/www/html/public/test-fpm.php"