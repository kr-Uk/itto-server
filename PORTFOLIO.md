# Itto Server - 인프라 구축 및 CI/CD 파이프라인

## 프로젝트 개요
Docker Compose 기반 프로덕션 서버 인프라를 설계하고 구축하여, Spring Boot 애플리케이션의 자동 빌드/배포 환경을 완성한 프로젝트

## 기술 스택
`AWS EC2` `Docker Compose` `Nginx` `Spring Boot 3.5` `PostgreSQL 16` `Redis 7` `MinIO` `GitHub Actions` `Cloudflare`

## 아키텍처
```
Client → Cloudflare(CDN/DNS) → Nginx(TLS 종료, 리버스 프록시)
                                  ├── Spring Boot API
                                  ├── PostgreSQL 16 / Redis 7
                                  └── MinIO (object storage)
```

## 주요 구현 내용

### 1. 컨테이너 기반 인프라 설계
- Docker Compose로 5개 서비스(App, Nginx, PostgreSQL, Redis, MinIO) 오케스트레이션
- 서비스 간 내부 네트워크 분리, 외부 노출은 Nginx(80/443)만 허용
- 프리티어 EC2(t3.micro 1GB)에서도 가동 가능한 슬림 구성

### 2. Nginx 리버스 프록시 및 보안
- 서브도메인 기반 라우팅 (`itto.hguitto.site`)
- HTTP → HTTPS 301 리다이렉트, 미등록 호스트 444 차단
- 보안 스캔 경로 차단 (.php, .env, wp-admin 등)
- 인증/회원가입 엔드포인트 rate limit (5r/m, 10r/m), 일반 API 30r/s
- Cloudflare 실제 IP 복원 (`CF-Connecting-IP`), X-Frame-Options/HSTS 등 보안 헤더

### 3. TLS 인증서
- Cloudflare Origin Certificate(와일드카드 `*.hguitto.site`)로 origin-edge 구간 암호화
- 발급 시 만료 길게 잡아 갱신 부담 최소화 (cert 교체만 reload)

### 4. CI/CD 파이프라인
- GitHub Actions: main 브랜치 push → Gradle 빌드 → Docker 이미지 빌드 → GHCR push → SSH 배포
- 무중단 이미지 교체 (`docker pull` → `docker compose up -d`)

### 5. 모니터링/관측성
- 외부 SaaS 조합으로 EC2 메모리 차지 0
  - **UptimeRobot**: 헬스체크 ping (다운 시 알림)
  - **Sentry**: 에러 트래킹
  - **AWS Budgets**: 비용 알람
- DAU 증가 시 Prometheus + Grafana 추가 도입 예정

### 6. 데이터 관리
- PostgreSQL 자동 백업 스크립트 (매일 03:00 UTC, 7일 보관, gzip 압축)
- Redis AOF 영속성 + 인메모리 LRU
- MinIO 사용자 사진 객체 스토리지
- 크레덴셜 `.env` 분리 관리 (chmod 600)

## 성과
- 코드 push만으로 프로덕션 배포까지 자동화 완성
- TLS, 백업, 보안 헤더/rate limit 등 운영 요소 구축
- 프리티어 단일 EC2 인스턴스에서 5개 서비스 안정 운영
