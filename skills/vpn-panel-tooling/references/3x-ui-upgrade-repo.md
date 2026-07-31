# 3x-ui-Upgrade Repository Structure

## Repository: ghjhdkysjtsjgz/3x-ui-Upgrade

### File Structure
```
3x-ui-Upgrade/
├── Dockerfile              (838 bytes)
├── README.md               (3.6 KB)
├── nginx.conf.template     (4.3 KB)
├── start.sh                (654 bytes)
└── sub-view.html           (25.4 KB)
```

### Dockerfile
- Base: `debian:bookworm-slim`
- Packages: curl, bash, ca-certificates, socat, tzdata, sqlite3, nginx, gettext-base
- Downloads Heimdall **v1.2.0** from `sh7CBAC/Heimdall/releases/download/v1.2.0/x-ui-linux-amd64.tar.gz`
- ⚠️ Note: This repo uses v1.2.0, NOT the latest v1.5.0
- Copies nginx.conf.template, start.sh, sub-view.html

### start.sh
- Sets NGINX_PORT=3000
- Configures x-ui: port 2053, webBasePath /managepanel/, admin/admin
- Starts x-ui in background
- Starts nginx in foreground on port 3000

### nginx.conf.template
- User-Agent detection for VPN apps (v2ray, V2Box, NekoBox, NekoRay, Shadowrocket, etc.)
- Routes:
  - `/managepanel/` → port 2053 (panel)
  - `/sub/` → port 2096 (subscription)
  - `/rawsub/` → port 2096/sub/ (raw subscription)
  - `/view/` → static HTML (subscription viewer)
  - `/` → port 8080 (inbound VLESS/WebSocket)
- Brand rewriting: Heimdall → MVPN

### sub-view.html
- 25KB single-page app
- Dark/light theme toggle
- Vazirmatn font (Persian)
- Features:
  - QR code generation
  - Usage stats display
  - Protocol detection (VLESS, VMess, Trojan, SS, HY2, TUIC)
  - Copy to clipboard
  - Telegram link: @saweg78

### Deployment on Railway
1. Fork repository to GitHub
2. Deploy from GitHub repo on Railway
3. Generate domain in Settings → Networking
4. Set Target Port to 3000
5. Access panel at: `https://your-domain.up.railway.app/managepanel/`
6. Default credentials: admin/admin

### Key Ports
- nginx: 3000 (external)
- x-ui: 2053 (internal)
- inbound: 8080 (internal)
- subscription: 2096 (internal)

### Database
- SQLite (default)
- Location: `/etc/x-ui/x-ui.db`
- ⚠️ Use Railway Volume at `/etc/x-ui` to persist data across redeploys

---

## User's Deployment: Mvpn2

### Repositories
- **Primary:** https://github.com/hzhhshsqioqjs/Heimdall-Railway (new account, Railway GitHub App installed)
- **Previous:** https://github.com/jshshshshwisi/Mvpn2 (GitHub App NOT installed on this account)
- **Created:** July 30, 2026
- **Heimdall Version:** v1.5.0 (latest)

### Differences from 3x-ui-Upgrade
- Uses Heimdall **v1.5.0** (not v1.2.0)
- Same file structure (Dockerfile, nginx.conf.template, start.sh, sub-view.html)
- Same nginx routing and brand rewriting (Heimdall → MVPN)

### Deployment
Same as 3x-ui-Upgrade: fork to GitHub → Railway → Generate Domain → Target Port 3000

### ⚠️ CRITICAL: Pattern A is the ONLY proven working approach
**Pattern B (full Heimdall clone without nginx) has FAILED repeatedly** on Railway despite multiple fix attempts:
- PORT→XUI_PORT bridging in start.sh → healthcheck still fails
- Binary rename trick (x-ui → x-ui.bin + wrapper) → healthcheck still fails  
- CACHE_BUST ARG in Dockerfile → old Docker layers still cached
- railway.json with empty healthcheckPath → Railway ignores it

**Root cause:** Without nginx listening on Railway's PORT, healthcheck always fails because x-ui stubbornly listens on 2053 regardless of XUI_PORT env var in some Railway environments.

**Final decision:** Copy the EXACT 3x-ui-Upgrade structure (Dockerfile, start.sh, nginx.conf.template, sub-view.html) but update Heimdall version to v1.5.0. This is what works.

---

## Two Deployment Patterns Summary

| | Pattern A (Minimal) | Pattern B (Full Clone) |
|---|---|---|
| **Repo** | 3x-ui-Upgrade / MVPN | Mvpn2 |
| **Files** | 4 files only | Full Heimdall repo |
| **Dockerfile** | nginx + x-ui + sub-view | x-ui only (pre-built binary) |
| **nginx** | Yes (port 3000) | No |
| **Brand rewrite** | Yes (Heimdall → MVPN) | No (original Heimdall) |
| **Domain port** | 3000 | 2053 |
| **TCP proxy** | 8080 | 8080 |
| **Credentials** | admin/admin | admin/admin |
| **User signal** | "میخوام پنل MVPN باشه" | "کلا پروژه هیمدال باشه اصلا تغییرش نده" |
