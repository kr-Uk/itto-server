# Itto Server - 인프라 구축 및 CI/CD 파이프라인

## 프로젝트 개요
Docker Compose 기반 프로덕션 서버 인프라를 설계하고 구축하여, Spring Boot 애플리케이션의 자동 빌드/배포 환경을 완성한 프로젝트

## 기술 스택
`AWS EC2` `Docker Compose` `Nginx` `Spring Boot 3.5` `PostgreSQL 16` `Redis 7` `GitHub Actions` `Prometheus` `Grafana` `Loki` `Cloudflare` `Let's Encrypt`

## 아키텍처
```
Client → Cloudflare(CDN/DNS) → Nginx(SSL 종료, 리버스 프록시)
                                  ├── Spring Boot API (포트 80)
                                  ├── Grafana 대시보드
                                  ├── PostgreSQL 16 / Redis 7
                                  └── Prometheus / Loki / Promtail
```

## 주요 구현 내용

### 1. 컨테이너 기반 인프라 설계
- Docker Compose로 9개 서비스(App, Nginx, PostgreSQL, Redis, Grafana, Prometheus, Loki, Promtail, Certbot) 오케스트레이션
- 서비스 간 내부 네트워크 분리, 외부 노출은 Nginx(80/443)만 허용

### 2. Nginx 리버스 프록시 및 보안
- 서브도메인 기반 라우팅 (`api.hguitto.site`, `grafana.hguitto.site`)
- HTTP → HTTPS 301 리다이렉트, 미등록 호스트 444 차단
- 보안 스캔 경로 차단 (.php, .env, wp-admin 등)
- X-Frame-Options, HSTS 등 보안 헤더 적용

### 3. SSL 인증서 자동화
- Let's Encrypt + Certbot 컨테이너로 인증서 자동 발급
- 12시간 주기 자동 갱신 + Nginx reload (Cron)

### 4. CI/CD 파이프라인
- GitHub Actions: main 브랜치 push → Gradle 빌드 → Docker 이미지 빌드 → GHCR push → SSH 배포
- 무중단 이미지 교체 (`docker pull` → `docker compose up -d`)

### 5. 모니터링 스택
- Prometheus로 메트릭 수집, Loki + Promtail로 컨테이너 로그 수집
- Grafana 대시보드로 시각화

### 6. 데이터 관리
- PostgreSQL 자동 백업 스크립트 (매일 03:00 UTC, 7일 보관, gzip 압축)
- Redis AOF 영속성 설정
- 크레덴셜 `.env` 분리 관리 (chmod 600)

## 성과
- 코드 push만으로 프로덕션 배포까지 자동화 완성
- SSL, 모니터링, 백업 등 운영에 필요한 요소를 모두 구축
- 단일 EC2 인스턴스(t3.small)에서 9개 서비스 안정 운영
