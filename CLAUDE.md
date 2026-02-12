# Itto Server

## Overview
Docker Compose 기반 인프라 서버 (hguitto.site)

## Architecture
```
Client → Cloudflare → Nginx (80/443) → App / Grafana
                                     → PostgreSQL, Redis (internal)
                                     → Prometheus, Loki, Promtail (monitoring)
```

## Services
| Service    | Container         | Port (internal) | Notes                          |
|------------|-------------------|-----------------|--------------------------------|
| nginx      | itto-nginx        | 80, 443         | Reverse proxy, SSL termination |
| app        | itto-app          | 80              | Spring Boot (ghcr.io/kr-uk/itto-backend) |
| postgres   | itto-postgres     | 5432            | PostgreSQL 16                  |
| redis      | itto-redis        | 6379            | Redis 7, AOF persistence       |
| grafana    | itto-grafana      | 3000            | Monitoring dashboard           |
| prometheus | itto-prometheus   | 9090            | Metrics collection             |
| loki       | itto-loki         | 3100            | Log aggregation                |
| promtail   | itto-promtail     | -               | Log shipper                    |
| certbot    | itto-certbot      | -               | SSL auto-renewal (12h loop)    |

## Domains
- `api.hguitto.site` → app (443 SSL)
- `grafana.hguitto.site` → grafana (443 SSL)
- HTTP requests → 301 redirect to HTTPS
- Unknown hosts → 444 (connection closed)

## Key Files
```
docker-compose.yml          # Service definitions
.env                        # Credentials (chmod 600)
secrets/
  firebase-service-account.json  # Firebase 서비스 계정 (chmod 600, CI/CD에서 생성)
nginx/conf.d/
  00-http.conf              # HTTP → HTTPS redirect + ACME challenge
  01-default-deny.conf      # Default server block (reject unknown hosts)
  10-api-https.conf         # API reverse proxy + scan path blocking
  20-grafana-https.conf     # Grafana reverse proxy
nginx/snippets/
  ssl-params.conf           # Shared SSL/security headers
certbot/conf/               # Let's Encrypt certificates
monitoring/
  prometheus/prometheus.yml  # Prometheus config
  grafana/provisioning/      # Grafana datasource provisioning
  loki/config.yml           # Loki config
  promtail/config.yml       # Promtail config
renew-certs.sh              # Cron script: nginx reload for cert renewal
backup-db.sh                # DB backup script (pg_dump, gzip, 7-day retention)
backups/                    # DB backup storage (*.sql.gz)
```

## Common Commands
```bash
# Container management
docker compose up -d              # Start all
docker compose ps                 # Status check
docker compose logs -f <service>  # Follow logs

# Nginx
docker exec itto-nginx nginx -t         # Test config
docker exec itto-nginx nginx -s reload   # Reload config

# PostgreSQL
docker exec -it itto-postgres psql -U itto -d itto

# Redis
docker exec -it itto-redis redis-cli
```

## Security Notes
- Credentials are in `.env` (not in docker-compose.yml)
- Firebase 서비스 계정: `secrets/firebase-service-account.json` → 환경변수 `FIREBASE_SERVICE_ACCOUNT`로 app 컨테이너에 전달
- Nginx blocks common scan paths (.php, .env, wp-admin, etc.)
- X-Frame-Options: DENY (API), SAMEORIGIN (Grafana)
- Certbot auto-renews every 12h; cron reloads nginx every 12h
- Nginx는 Docker DNS resolver (`127.0.0.11`, 10s TTL)를 사용하여 app/grafana 컨테이너 재생성 시 자동으로 새 IP를 resolve (수동 reload 불필요)

## Git Repositories
| Repo | Description |
|------|-------------|
| `kr-Uk/itto-server` (private) | 인프라 설정 (이 레포, `/opt/itto`) |
| `kr-Uk/itto-backend` | Spring Boot 백엔드 앱 |

## CI/CD
- GitHub repo: `kr-Uk/itto-backend`
- main push → GitHub Actions → GHCR 이미지 빌드 → SSH 배포 → `docker compose up -d app`
- GHCR 이미지: `ghcr.io/kr-uk/itto-backend:latest`
- GitHub Secrets: `SSH_HOST`, `SSH_USER`, `SSH_KEY`, `GHCR_TOKEN`, `FIREBASE_SERVICE_ACCOUNT_JSON`
- 배포 스크립트: firebase JSON을 base64 디코딩 → `secrets/firebase-service-account.json` 생성 후 `docker compose up -d app`

## Crontab
```
0 */12 * * * /opt/itto/renew-certs.sh                                       # Nginx reload for cert renewal
0 3 * * *   /opt/itto/backup-db.sh >> /opt/itto/backups/backup.log 2>&1     # Daily DB backup (03:00 UTC, 7-day retention)
```
