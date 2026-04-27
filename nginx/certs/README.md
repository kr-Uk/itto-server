# Nginx TLS 인증서 디렉토리

Cloudflare Origin Certificate(`*.hguitto.site` 와일드카드)를 이 디렉토리에 두면
nginx 컨테이너가 `/etc/nginx/certs/`로 마운트해서 사용합니다.

## 필요한 파일 두 개

```
hguitto.site.pem   # Cloudflare Origin Certificate (PEM)
hguitto.site.key   # Cloudflare Origin Private Key (PEM)
```

## 업로드 방법

EC2에 배포된 `~/itto-app/server/nginx/certs/` 경로에 두 파일을 업로드:

```bash
# 로컬에서:
scp hguitto.site.pem hguitto.site.key ec2:~/itto-app/server/nginx/certs/

# EC2에서 권한 정리:
chmod 644 hguitto.site.pem
chmod 600 hguitto.site.key
```

## 적용

```bash
docker compose exec nginx nginx -t      # 문법 체크
docker compose exec nginx nginx -s reload   # 무중단 reload
```

## 갱신

Cloudflare Origin Cert는 발급 시 만료를 길게(15년) 잡을 수 있어서
Let's Encrypt처럼 자동 갱신이 필요 없습니다. 만료 임박 시 Cloudflare 대시보드에서
재발급 후 위 두 파일을 교체하고 reload만 하면 끝.

이 디렉토리는 `.gitignore`로 커밋되지 않습니다.
