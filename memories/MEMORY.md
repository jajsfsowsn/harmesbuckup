Git clone with embedded PAT (https://ghp_xxx@github.com/...) requires `GIT_TERMINAL_PROMPT=0` to avoid hanging on credential prompts. Use `--depth 1` for faster initial clone. Port 22 often blocked in cloud environments, use HTTPS (port 443) instead.
§
Works with VLESS+XHTTP+Reality VPN configs on 3x-ui panels hosted on Railway. GitHub repo for backups: github.com/jajsfsowsn/harmesbuckup. Backup cron job runs every 12h (job_id: 1810abe48302).
§
User's Vercel account: mehrdad6. Token: vcp_REDACTED_FOR_GITHUB_PUSH. Main project: mvpndeployer-deploy. Padding: 0-0. Uses NapsterNetV. GitHub accounts: jajsfsowsn (primary), jshshshshwisi (workflow scope). Android VPN app: github.com/jshshshshwisi/RofghaVPN — pre-built Xray binaries via GitHub Actions.
§
Vercel deployer (mvpndeployer-deploy): deploys 3x-ui-Upgrade to Railway, VLESS+XHTTP+Reality, client "Mvpn" (100GB/30days), xPaddingBytes: '0-0'. API: /api/connect, /api/deploy, /api/create-inbound, /api/tcp. Panel default: admin/admin. Inbound port 8080. Path: /mehrdad.
§
3x-ui panel API (this fork): login at /login (POST JSON), CSRF from /csrf-token. Inbound list: GET /panel/api/inbounds/list/slim. Add inbound: POST /panel/api/inbounds/add (form-urlencoded). Delete: POST /panel/api/inbounds/del/{id}. Restart: POST /panel/api/xray/restart. Cookie: 3x-ui.
§
Hermes backup cron job (ID: 1810abe48302) runs every 12h, backs up ~/.hermes to GitHub repo jajsfsowsn/harmesbuckup via HTTPS. Backup script at /data/hermes-backup/backup.sh. Backs up: memories, skills, config, SOUL.md, sessions, cron. Excludes state.db (tokens). GitHub PAT was provided for this repo.
§
User prefers autonomous execution — when asked to do something, DO IT, don't suggest alternatives or ask them to do it. "خودت انجام بده" = do it yourself, not "you do this step".