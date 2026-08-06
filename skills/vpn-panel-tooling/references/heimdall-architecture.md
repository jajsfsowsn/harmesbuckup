# Heimdall Architecture (sh7CBAC/Heimdall)

## Overview
Heimdall is a powerful enhanced Xray management panel built for cleaner operations, smarter subscriptions, and real-world infrastructure control.

## Repository
- **URL:** https://github.com/sh7CBAC/Heimdall
- **Stars:** 33
- **Forks:** 9
- **Language:** Go
- **License:** GPL-3.0
- **Latest Version:** v1.5.0 (29 July 2026)

## Tech Stack
- **Backend:** Go 1.26, Gin, GORM
- **Frontend:** React 19, Ant Design 6, Vite 8, TypeScript
- **Database:** SQLite (default), PostgreSQL (optional)
- **Xray:** Xray-core (managed child process)

## Key Features

### Multi-Profile Inbounds
- Single inbound serves multiple independent subscription profiles
- Each profile has its own: address, transport, security mode, display behavior, subscription output
- Supports: TCP/RAW, mKCP, WebSocket, HTTPUpgrade, gRPC, XHTTP

### Per-Client Speed & Connection Limits
- Separate upload/download speed limits per client
- Concurrent connection limits
- Fair usage policies

### Client Activity Monitoring
- Optional visibility into selected clients
- Review observed destinations, traffic usage, activity patterns

### Hidden Infrastructure
- Hide inbound remarks, outbound tags, balancer tags, client emails

### Smart Subscription Links
- Customized Ourenus-based subscription template

### Iran Direct Routing
- Dedicated routing for Iranian domains and IP ranges

## File Structure
```
Heimdall/
├── .github/                  (CI/CD workflows)
├── deploy/                   (Deployment scripts)
├── docs/                     (Documentation - Next.js)
├── frontend/                 (React + Ant Design)
├── internal/                 (Go backend)
│   ├── config/               (Environment parsing)
│   ├── database/             (GORM schema)
│   ├── xray/                 (Xray lifecycle)
│   ├── mtproto/              (MTProto inbounds)
│   ├── sub/                  (Subscription server)
│   ├── web/                  (Gin server + API)
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── install.sh
└── .env.example
```

## Configuration
- **Port:** 2053 (default, via XUI_PORT env var)
- **Database:** SQLite at `/etc/x-ui/x-ui.db`
- **Credentials:** admin/admin (set via `./x-ui setting -username admin -password admin`)

---

## Railway Deployment: Two Patterns

### Pattern A: Minimal (3x-ui-Upgrade / MVPN)
Strip repo to 4 files. Adds nginx reverse proxy, brand rewriting, subscription viewer.
- **Files:** Dockerfile, nginx.conf.template, start.sh, sub-view.html
- **Ports:** nginx:3000, x-ui:2053, inbound:8080
- **Domain port:** 3000
- **Source repo:** `ghjhdkysjtsjgz/3x-ui-Upgrade`

### Pattern B: Full Clone (Mvpn2)
Clone entire Heimdall repo, only change Dockerfile. No nginx, no source modifications.
- **Files:** Full repo + modified Dockerfile + start.sh + railway.json
- **Ports:** x-ui:2053 (direct)
- **Domain port:** 2053
- **Source repo:** `jshshshshwisi/Mvpn2`

### Pattern B: Dockerfile
```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash ca-certificates socat tzdata sqlite3 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -L https://github.com/sh7CBAC/Heimdall/releases/download/v1.5.0/x-ui-linux-amd64.tar.gz -o /tmp/x-ui.tar.gz \
    && tar -xzf /tmp/x-ui.tar.gz -C /usr/local/ && rm /tmp/x-ui.tar.gz \
    && chmod +x /usr/local/x-ui/x-ui
RUN mkdir -p /etc/x-ui /var/log/x-ui
WORKDIR /usr/local/x-ui
COPY start.sh /start.sh && chmod +x /start.sh
ENV XUI_IN_DOCKER="true" XUI_MAIN_FOLDER="/usr/local/x-ui" XUI_DB_FOLDER="/etc/x-ui" XUI_PORT=2053
EXPOSE 2053
CMD ["/start.sh"]
```

### Pattern B: start.sh
```sh
#!/bin/sh
set -eu
PORT="${XUI_PORT:-${PORT:-2053}}"
export XUI_PORT=$PORT
exec /usr/local/x-ui/x-ui
```

### Pattern B: railway.json
```json
{
  "build": { "builder": "DOCKERFILE", "dockerfilePath": "Dockerfile" },
  "deploy": { "startCommand": "./x-ui", "restartPolicyType": "ON_FAILURE" }
}
```

### Key Notes
- Heimdall v1.5.0 release only has `x-ui-linux-amd64.tar.gz` (82MB) — no ARM builds
- Original Heimdall Dockerfile builds from source (Go+Node multi-stage) — too heavy for Railway
- Keep `Dockerfile.original` as backup when replacing with pre-built binary approach
- Railway sets `PORT` env; Heimdall reads `XUI_PORT` — start.sh must bridge them
- Volume at `/etc/x-ui` recommended to persist SQLite database across redeploys
