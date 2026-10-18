<h1 align="center">ITTO Server</h1>

<p align="center">
  ITTO 서비스를 한 대의 서버에서 운영하기 위한 Docker Compose 인프라
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Docker%20Compose-2496ED?style=flat-square&logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Nginx-009639?style=flat-square&logo=nginx&logoColor=white"/>
  <img src="https://img.shields.io/badge/Prometheus-E6522C?style=flat-square&logo=prometheus&logoColor=white"/>
  <img src="https://img.shields.io/badge/Grafana-F46800?style=flat-square&logo=grafana&logoColor=white"/>
</p>

![ITTO 시스템 구조](docs/portfolio/architecture.png)

## 구성

| 역할 | 서비스 |
|---|---|
| 진입점·TLS | Nginx · Certbot |
| 애플리케이션 | Spring Boot API |
| 데이터 | PostgreSQL 16 · Redis 7 · MinIO |
| 메트릭 | Prometheus · Grafana |
| 로그 | Loki · Promtail |

관련 저장소: [Backend](https://github.com/kr-Uk/itto-backend) · [Flutter 앱](https://github.com/kr-Uk/itto-frontend)

## 설계 포인트

- 외부 요청은 Nginx에서 받고 API와 Grafana 경로를 분리합니다.
- PostgreSQL, Redis, MinIO와 모니터링 서비스는 내부 Docker 네트워크에서 통신합니다.
- 애플리케이션 컨테이너에 health check를 두고 각 컨테이너의 메모리 한도를 명시했습니다.
- Docker 로그는 파일 크기와 개수를 제한해 디스크 사용량을 통제합니다.
- 비밀값과 Firebase 서비스 계정은 환경 변수와 서버의 별도 파일로 주입합니다.

## 실행

```bash
# docker-compose.yml에서 참조하는 값을 로컬 .env에 설정
docker compose up -d
docker compose ps
```

공개 저장소에는 실제 `.env`, 인증서, Firebase 서비스 계정 파일이 포함되지 않습니다.

## 저장소 상태

프로젝트 종료 시점의 구성을 포트폴리오용으로 공개한 읽기 전용 저장소입니다.
