# Railway Deployment Reference

## Active Deployments
### Mvpn2 (Heimdall v1.5.0)
- **URL**: `https://heimdall-railway-production.up.railway.app`
- **Panel**: `https://heimdall-railway-production.up.railway.app/managepanel/`
- **Panel Login**: admin/admin
- **GitHub repo**: `hzhhshsqioqjs/Mvpn2`
- **GitHub token**: `[REDACTED_GITHUB_TOKEN]` (hzhhshsqioqjs)
- **GitHub App**: installed on `hzhhshsqioqjs` account
- **Railway project**: `lucky-youth` (ID: `5d7c82d4-2c4a-4008-a83d-7425adefd343`)
- **Railway token**: `[REDACTED_RAILWAY_TOKEN]` (project-scoped)

### 3x-ui-Upgrade (Reference/Working)
- **URL**: `https://3x-ui-upgrade-production-e554.up.railway.app`
- **GitHub repo**: `ghjhdkysjtsjgz/3x-ui-Upgrade`
- **Heimdall v1.2.0** + nginx reverse proxy

## Multi-Account Layout
- `jshshshshwisi` = primary VPN repos (RofghaVPN, old Mvpn2)
- `hzhhshsqioqjs` = Railway deployments (GitHub App installed here)
- `mehrdad6` = Vercel (mvpndeployer-deploy)

## Port Mapping
| Port | Service | Notes |
|------|---------|-------|
| `${PORT:-3000}` | nginx (entry) | Railway healthcheck hits this |
| `2053` | x-ui panel | Internal, set via `./x-ui setting -port 2053` |
| `2096` | Sub server | Default in Heimdall DB |
| `8080` | VPN inbound | Xray listens here |

## nginx Routing Rules
- `/managepanel/` → x-ui panel (2053)
- `/sub/[id]` → VPN apps get raw text (2096), browsers get sub-view.html
- `/rawsub/[id]` → always raw text from sub server (2096)
- `/view/` → static HTML subscription page
- `/` → VPN inbound (8080)

## File Structure (Mvpn2)
```
Mvpn2/
├── Dockerfile            # debian:bookworm-slim + nginx + Heimdall v1.5.0
├── start.sh              # starts x-ui (2053) + nginx (PORT)
├── nginx.conf.template   # reverse proxy config
├── sub-view.html         # subscription page
├── .dockerignore         # excludes .git, node_modules, etc.
├── internal/             # Heimdall Go source (untouched)
├── frontend/             # Heimdall React frontend (untouched)
└── ...
```

## Railway API Quick Reference
```bash
# List projects (needs account-scoped token)
railway api '{ projects(first: 10) { edges { node { id name } } } }'

# Create project
railway api 'mutation { projectCreate(input: { name: "X" }) { id name } }'

# Create service from GitHub
railway api 'mutation { serviceCreate(input: { projectId: "ID", name: "X", source: { repo: "owner/repo" } }) { id name } }'

# Trigger deploy (requires GitHub App on repo owner's account)
railway api 'mutation { deploymentTriggerCreate(input: { serviceId: "ID", branch: "main", environmentId: "ID", projectId: "ID", provider: "GITHUB", repository: "owner/repo" }) { id } }'
```

## Known Issues & Workarounds
1. **Railway CLI rejects API tokens** — only `railway api` works with token auth
2. **Dashboard Start command overrides railway.json** — clear it or use wrapper script
3. **Docker cache** — use `ARG REBUILD=<timestamp>` before COPY
4. **GitHub App "Bad Access"** — repo owner ≠ App installation account
5. **Account verification** — new Railway accounts need email verification for tokens
6. **Domain requires port** — set PORT=3000 variable or ensure nginx reads Railway PORT
