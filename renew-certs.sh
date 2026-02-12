#!/bin/sh
# Reload nginx to pick up renewed SSL certificates
# Run via cron: 0 */12 * * * /opt/itto/renew-certs.sh
docker exec itto-nginx nginx -s reload 2>/dev/null || true
