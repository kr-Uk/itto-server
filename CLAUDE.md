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

## Troubleshooting Log

### 2026-02-12
1. **Nginx 설정 마운트 안 됨 (서버 접속 불가)**
   - 증상: 모든 컨테이너 Up인데 외부 접속 불가, 컨테이너 내부 `/etc/nginx/conf.d/` 비어있음
   - 원인: git pull 등으로 호스트의 `nginx/conf.d/` 디렉토리가 재생성되면서 Docker bind mount가 기존 inode를 참조
   - 해결: `docker compose restart nginx`

2. **API 403 에러 (SecurityConfig 경로 불일치)**
   - 증상: `/api/v1/auth/login`, `/api/v1/hobbies` 등에서 403
   - 원인: 기존 SecurityConfig의 permitAll 경로가 `/api/...`였으나, 새 배포에서 컨트롤러가 `/api/v1/...`로 변경됨
   - 해결: 백엔드에서 SecurityConfig도 `/api/v1/...`로 업데이트하여 재배포

3. **`/api/v1/system/version` 500 에러**
   - 증상: version API 호출 시 500
   - 원인: `platform` 필수 쿼리 파라미터 누락 시 500, 파라미터 포함해도 DB에 데이터 없어서 404
   - 해결: `app_versions` 테이블에 ANDROID/IOS 초기 데이터 INSERT (`min_version: 1.0.0`, `latest_version: 1.0.0`)

4. **Nginx DNS 캐시로 인한 배포 후 수동 reload 필요**
   - 증상: app 컨테이너 재생성 후 nginx가 이전 IP를 캐시하여 502/503
   - 해결: `resolver 127.0.0.11 valid=10s` + 변수 기반 `proxy_pass` 적용 → 배포 시 자동 resolve
