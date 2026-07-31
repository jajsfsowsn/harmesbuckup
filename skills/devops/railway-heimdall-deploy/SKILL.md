---
name: railway-heimdall-deploy
description: Deploy Heimdall VPN panel on Railway with nginx.
triggers:
  - railway deploy heimdall
  - deploy vpn panel railway
---

# Railway Heimdall Deployment

## Key Architecture
Railway assigns a `PORT` env var. Healthcheck hits that port. Heimdall/x-ui listens on 2053 internally. **nginx** must sit in front, listening on Railway's PORT.

## Working Pattern (from 3x-ui-Upgrade)
- **nginx** on `${PORT:-3000}` (Railway's assigned port)
- **x-ui** on port 2053 (internal)
- **Healthcheck** hits nginx, gets response ✅

## Critical Fix
```bash
# WRONG - healthcheck fails
export NGINX_PORT=3000

# RIGHT - uses Railway's PORT
export NGINX_PORT="${PORT:-3000}"
```

## Files Required
1. `Dockerfile` - debian + nginx + Heimdall binary
2. `start.sh` - starts x-ui on 2053, nginx on Railway PORT
3. `nginx.conf.template` - reverse proxy config
4. `sub-view.html` - subscription page (optional)

## start.sh Template
```bash
#!/bin/bash
set -e
export NGINX_PORT="${PORT:-3000}"
cd /usr/local/x-ui
./x-ui setting -port 2053 -webBasePath /managepanel/ -username admin -password admin || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
./x-ui &
sleep 2
exec nginx -g "daemon off;"
```

## Railway Dashboard Settings
- **Start Command**: `/start.sh`
- **Healthcheck Path**: `/` (nginx responds)
- **Target Port**: matches Railway's PORT (auto)

## Dockerfile Template (with cache bust)
```dockerfile
FROM debian:bookworm-slim
# Reliable cache bust — change value each deploy
RUN echo "REBUILD 2026-07-30-08" > /tmp/rebuild
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash ca-certificates socat tzdata sqlite3 nginx gettext-base \
    && ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime \
    && rm -rf /var/lib/apt/lists/*
RUN curl -L https://github.com/sh7CBAC/Heimdall/releases/download/v1.5.0/x-ui-linux-amd64.tar.gz -o /tmp/x-ui.tar.gz \
    && tar -xzf /tmp/x-ui.tar.gz -C /usr/local/ && rm /tmp/x-ui.tar.gz && chmod +x /usr/local/x-ui/x-ui
RUN mkdir -p /etc/x-ui /var/log/x-ui
COPY nginx.conf.template /etc/nginx/nginx.conf.template
ARG START_DATE=2026073007
COPY start.sh /start.sh
RUN chmod +x /start.sh
RUN mkdir -p /usr/share/nginx/html/view
COPY sub-view.html /usr/share/nginx/html/view/index.html
CMD ["/start.sh"]
```

## Common Pitfalls
1. **Hardcoding NGINX_PORT=3000** → healthcheck fails. Always use `${PORT:-3000}`
2. **Docker layer caching** → Railway aggressively caches layers. `ARG REBUILD=<timestamp>` alone may NOT bust cached COPY layers. Use `RUN echo "REBUILD 2026-07-30-08" > /tmp/rebuild` as the FIRST instruction after FROM — this changes the instruction hash and forces all subsequent layers to rebuild. If build logs show "cached" on COPY steps, the bust failed. Also add `# cache-bust: <date>-vN` comment above each COPY line as secondary insurance.
3. **GitHub App "Bad Access" error** → means App is installed on the WRONG GitHub account. `deploymentTriggerCreate` returns "Bad Access" when the repo owner ≠ the account where the App is installed. Fix: create the repo on the account where the App IS installed (or install the App on the repo owner's account). Verify which account a token belongs to: `curl -H "Authorization: token $TOKEN" https://api.github.com/user`
4. **GitHub App not installed** → deploy via Dashboard manually. Token-based API can create projects/services but can't trigger GitHub deploys.
5. **Missing nginx** → x-ui on 2053 doesn't respond to healthcheck. nginx is REQUIRED as reverse proxy.
6. **Railway CLI rejects API tokens** — only `railway api '{graphql}'` works with token auth. `whoami`, `link`, `up` all fail with "Invalid RAILWAY_TOKEN".
7. **Railway Dashboard "Start command" overrides railway.json** — if dashboard has `./x-ui`, it ignores config files. Clear it or use wrapper script approach.
8. **Wrapper script trick**: rename `x-ui` → `x-ui.bin`, replace with shell script that sets env and exec's `.bin`. Works even when Start command is hardcoded.
9. **Railway account verification** — new Railway accounts need email verification before creating project tokens. Some features require paid plans. Work around by using Dashboard directly.
10. **Domain requires port config** — after deploying, Railway may ask for port configuration before Generate Domain works. Set `PORT=3000` as a Railway variable OR ensure nginx reads Railway's PORT via `${PORT:-3000}`.

## Workflow Rules (User Preferences)
- **Autonomous execution**: User says "خودت انجام بده" = do it yourself, don't suggest alternatives or ask for permission
- **Copy-paste ready code**: When sharing configs/commands, always use triple-backtick code blocks for easy copying
- **Quick diagnosis**: User gets frustrated with repeated errors — diagnose FAST, fix FAST
- **Don't ask, just do**: When user provides a token or says "go ahead", execute immediately without confirmation prompts
- **Copy working patterns**: When a reference project (3x-ui-Upgrade) works, copy its EXACT structure instead of reinventing — user explicitly said "شبیه بالای بسازنش" (build it like the one above)

## Heimdall Port Map
| Port | Service | Notes |
|------|---------|-------|
| `${PORT:-3000}` | nginx (entry) | Railway healthcheck hits this |
| `2053` | x-ui panel | Internal, set via `./x-ui setting -port 2053` |
| `2096` | Sub server | Serves subscription links, default in DB |
| `8080` | VPN inbound | Xray listens here for VPN traffic |

nginx routes: `/managepanel/` → 2053, `/sub/` → 2096 (apps) or static HTML (browsers), `/rawsub/` → 2096, `/` → 8080

## Sub Page Troubleshooting
- `/sub/[id]` must be accessed with the full sub ID from the panel
- `/sub/` without ID shows the static `sub-view.html` page
- `/rawsub/[id]` proxies to x-ui sub server on 2096 (for VPN apps)
- If sub page is blank: check that x-ui sub server is running (port 2096), and the inbound has a sub ID configured
- **`/sub/` returns 404** → usually means Docker cache didn't include `sub-view.html` in the image. Check build logs for "cached" on the `COPY sub-view.html` step. Fix: add `RUN echo "REBUILD $(date)" > /tmp/rebuild` before the COPY instructions.

## Python API Pattern
For scripting Heimdall API calls in Python, use `requests.Session()` to maintain cookies across requests. Individual `curl` calls lose the session cookie between requests, causing 404 on subsequent API calls. See `references/railway-deployment.md` for full example.

## Railway API Quick Reference
- List projects: `{ projects(first: 10) { edges { node { id name } } } }`
- Create project: `mutation { projectCreate(input: { name: "X" }) { id name } }`
- Create service: `mutation { serviceCreate(input: { projectId, name, source: { repo: "owner/repo" } }) { id name } }`
- Trigger deploy: `mutation { deploymentTriggerCreate(input: { serviceId, branch, environmentId, projectId, provider: "GITHUB", repository: "owner/repo" }) { id } }`
- Most queries return "Not Authorized" with project-scoped tokens — projectCreate/serviceCreate work, queries often don't

## Heimdall Panel API Authentication
Heimdall uses session-based auth with CSRF tokens. API routes are under `/managepanel/panel/api/...`.

### Login Flow (curl)
```bash
COOKIEJAR="/tmp/rail_cookies.txt"
# 1. Get CSRF token
CSRF=$(curl -s -c "$COOKIEJAR" "https://DOMAIN/managepanel/csrf-token" | jq -r '.obj')
# 2. Login
curl -s -b "$COOKIEJAR" -c "$COOKIEJAR" \
  -X POST "https://DOMAIN/managepanel/login" \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: $CSRF" \
  -d '{"username":"admin","password":"admin"}'
# 3. Use session cookie for API calls
curl -s -b "$COOKIEJAR" "https://DOMAIN/managepanel/panel/api/inbounds/list/slim"
```

### Key API Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/managepanel/csrf-token` | GET | Get CSRF token |
| `/managepanel/login` | POST | Login (username, password) |
| `/managepanel/logout` | POST | Logout |
| `/managepanel/panel/api/inbounds` | POST | Create inbound |
| `/managepanel/panel/api/inbounds/list/slim` | GET | List inbounds |
| `/managepanel/panel/api/inbounds/{id}` | PUT | Update inbound |
| `/managepanel/panel/api/inbounds/{id}` | DELETE | Delete inbound |
| `/managepanel/panel/api/inbounds/{id}/del` | POST | Delete inbound (alt) |
| `/managepanel/panel/api/server/getData` | GET | Server stats |
| `/managepanel/panel/api/xray/restart` | POST | Restart Xray |

### x-ui CLI Setting Command
Only these flags are supported:
```
-port, -webBasePath, -username, -password, -listenIP,
-webCert, -webCertKey, -tgbottoken, -tgbotchatid,
-enabletgbot, -reset, -show, -resetTwoFactor,
-getListen, -getCert, -getApiToken, -tgbotRuntime
```
No `-subPort` flag — sub port (2096) is stored in DB only.

## Xray Startup Requirements
- **Xray needs at least one inbound** to start — otherwise `config.json` is empty and Xray refuses to start
- After creating the first inbound via panel, Xray can be started
- Restart Xray via panel button or API: `POST /managepanel/panel/api/xray/restart`
- Reality inbounds require valid private/public key pair (generated by Heimdall)

## References
- Source repo: `ghjhdkysjtsjgz/3x-ui-Upgrade`
- Heimdall releases: `github.com/sh7CBAC/Heimdall/releases`
- Heimdall architecture: `github.com/sh7CBAC/Heimdall/blob/main/CLAUDE.md`
