#!/bin/bash
set -e

echo "=== Planting attachment via the REAL, unmodified uvdesk/core-framework Localhost.php upload manager ==="
php /var/www/app/poc-harness/run.php

echo
echo "=== Filesystem proof: what's actually sitting in the web-served public/assets tree ==="
find /var/www/app/public/assets -type f -exec ls -la {} \;

echo
echo "=== Starting Apache ==="
apache2-foreground
