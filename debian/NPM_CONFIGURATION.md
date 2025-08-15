# Nginx Proxy Manager Configuration for Invoice Ninja

## Architecture Overview
Since we're connecting directly to PHP-FPM (no nginx container), NPM needs to handle both static files and PHP processing.

## Prerequisites
- Invoice Ninja running with `docker-compose.production.yml`
- PHP-FPM accessible on port 9000
- NPM installed on separate VPS
- Domain pointing to NPM server

## Step 1: Add Proxy Host in NPM

### Details Tab:
- **Domain Names**: `invoice.yourdomain.com`
- **Scheme**: `http`
- **Forward Hostname/IP**: `YOUR_INVOICE_NINJA_VPS_IP`
- **Forward Port**: `9000`
- **Cache Assets**: ❌ Disabled (we'll handle this in custom config)
- **Block Common Exploits**: ✓ Enabled
- **Websockets Support**: ✓ Enabled

## Step 2: Custom Nginx Configuration

Add this **complete configuration** to the **Advanced** tab:

```nginx
# Root directory for Invoice Ninja
root /data/invoiceninja/public;

# Index file
index index.php index.html;

# Client upload size
client_max_body_size 100M;

# Timeouts for large operations
proxy_connect_timeout 600;
proxy_send_timeout 600;
proxy_read_timeout 600;
send_timeout 600;
fastcgi_read_timeout 600;

# FastCGI buffer sizes
fastcgi_buffer_size 128k;
fastcgi_buffers 4 256k;
fastcgi_busy_buffers_size 256k;

# Location for static files (bypass PHP)
location ~* \.(jpg|jpeg|gif|png|css|js|ico|svg|woff|woff2|ttf|eot|map)$ {
    # Since NPM doesn't have the files locally, proxy to the app container
    proxy_pass http://YOUR_INVOICE_NINJA_VPS_IP:9000;
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
}

# Main location block
location / {
    # Try static files first, then pass to PHP
    try_files $uri $uri/ /index.php?$query_string;
}

# PHP processing
location ~ \.php$ {
    # Prevent PHP execution in uploads
    location ~ /storage/ {
        return 403;
    }
    
    # FastCGI configuration
    fastcgi_pass YOUR_INVOICE_NINJA_VPS_IP:9000;
    fastcgi_index index.php;
    
    # CRITICAL: Set the correct SCRIPT_FILENAME
    # This path must match the container's internal path
    fastcgi_param SCRIPT_FILENAME /var/www/html/public$fastcgi_script_name;
    fastcgi_param DOCUMENT_ROOT /var/www/html/public;
    
    # Pass HTTPS status to PHP
    fastcgi_param HTTPS on;
    fastcgi_param HTTP_SCHEME https;
    
    # Real IP forwarding
    fastcgi_param REMOTE_ADDR $remote_addr;
    fastcgi_param HTTP_X_REAL_IP $remote_addr;
    fastcgi_param HTTP_X_FORWARDED_FOR $proxy_add_x_forwarded_for;
    fastcgi_param HTTP_X_FORWARDED_PROTO https;
    fastcgi_param HTTP_X_FORWARDED_HOST $host;
    
    # Include standard FastCGI params
    include fastcgi_params;
    
    # Override some params for proper operation
    fastcgi_param SERVER_NAME $host;
    fastcgi_param SERVER_PORT 443;
}

# Block access to sensitive files
location ~ /\.(ht|env) {
    deny all;
}

location ~ /\. {
    deny all;
}

# Storage access (for uploaded files)
location /storage/ {
    # Directly proxy to PHP-FPM for storage files
    proxy_pass http://YOUR_INVOICE_NINJA_VPS_IP:9000;
    expires 1y;
    add_header Cache-Control "public";
}

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

**IMPORTANT**: Replace `YOUR_INVOICE_NINJA_VPS_IP` with your actual Invoice Ninja server IP address in ALL locations above.

## Step 3: SSL Configuration

### SSL Tab:
- **SSL Certificate**: Request a new SSL Certificate
- **Force SSL**: ✓ Enabled
- **HSTS Enabled**: ✓ Enabled
- **HSTS Subdomains**: ❌ Disabled (unless using subdomains)
- **HTTP/2 Support**: ✓ Enabled
- **Email**: `admin@yourdomain.com`

## Step 4: Alternative Simpler Configuration

If the above doesn't work, try this simpler approach where NPM just forwards everything:

```nginx
# Simpler configuration - just forward everything to PHP-FPM
location / {
    fastcgi_pass YOUR_INVOICE_NINJA_VPS_IP:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME /var/www/html/public/index.php;
    fastcgi_param DOCUMENT_ROOT /var/www/html/public;
    fastcgi_param HTTPS on;
    fastcgi_param HTTP_SCHEME https;
    include fastcgi_params;
}

# Client upload size
client_max_body_size 100M;

# Timeouts
fastcgi_read_timeout 600;
```

## Step 5: Firewall Configuration

On your Invoice Ninja VPS:

```bash
# Allow PHP-FPM port only from NPM server
sudo ufw allow from NPM_SERVER_IP to any port 9000

# Deny public access to PHP-FPM
sudo ufw deny 9000

# Allow SSH
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable
```

## Testing

### 1. Test PHP-FPM Connection
From NPM server:
```bash
telnet INVOICE_NINJA_IP 9000
# Should connect successfully
```

### 2. Test FastCGI
Create a test file:
```bash
# On Invoice Ninja server
docker compose exec app bash -c "echo '<?php phpinfo();' > /var/www/html/public/test.php"
```
Then visit: https://invoice.yourdomain.com/test.php

### 3. Check Logs
```bash
# On Invoice Ninja server
docker compose logs -f app

# On NPM server
docker logs nginx-proxy-manager
```

## Troubleshooting

### Issue: 502 Bad Gateway
- Check PHP-FPM is running: `docker compose ps`
- Check port 9000 is accessible from NPM server
- Verify firewall rules

### Issue: 404 Not Found
- Check SCRIPT_FILENAME path is correct
- Verify /var/www/html/public path in container

### Issue: White page
- Check APP_URL in .env.production uses https://
- Verify TRUSTED_PROXIES is set correctly
- Check PHP error logs: `docker compose logs app`

### Issue: Assets not loading
- Check browser console for 404 errors
- Verify static file location blocks
- Clear browser cache

### Issue: File uploads fail
- Increase client_max_body_size in NPM config
- Check PHP post_max_size and upload_max_filesize

## Security Notes

1. **Never expose port 9000 publicly** - Only allow NPM server
2. **Use specific IP in TRUSTED_PROXIES** if possible
3. **Regular updates**: Keep both NPM and Invoice Ninja updated
4. **Monitor logs** for suspicious activity
5. **Backup regularly** before updates

## Performance Optimization

For better performance, consider:

1. **Enable FastCGI cache** in NPM:
```nginx
fastcgi_cache_path /tmp/nginx_cache levels=1:2 keys_zone=invoiceninja:10m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";

location ~ \.php$ {
    fastcgi_cache invoiceninja;
    fastcgi_cache_valid 200 60m;
    # ... rest of PHP config
}
```

2. **Use Redis for sessions** (already configured in .env.production)

3. **Enable OPcache** in PHP (already enabled in Docker image)