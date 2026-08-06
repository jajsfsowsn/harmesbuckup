# Vercel API Notes (for VPN Panel Tooling)

## Authentication
```bash
export VERCEL_TOKEN="[REDACTED_TOKEN]"
# Or pass as header:
# Authorization: Bearer [REDACTED_TOKEN]
```

## Key Endpoints

### List Projects
```
GET https://api.vercel.com/v9/projects
Header: Authorization: Bearer {token}
```

### Project Details
```
GET https://api.vercel.com/v9/projects/{projectId}
```

### List Deployments
```
GET https://api.vercel.com/v6/deployments?projectId={id}&limit=10
```

### Get Deployment Files (⚠️ v8 only — v5 is disabled)
```
GET https://api.vercel.com/v8/now/deployments/{deployId}/files
```
Returns file tree with UIDs. Then fetch individual files:
```
GET https://api.vercel.com/v8/now/deployments/{deployId}/files/{fileUid}
```
Response: `{"data": "<base64-encoded-content>"}`

### Environment Variables
```
GET https://api.vercel.com/v9/projects/{projectId}/env
```
⚠️ Returns `{"envs": []}` if no vars set. Hidden vars not shown without project link.

### CLI Auth
```bash
# Token-based (non-interactive):
VERCEL_TOKEN=[REDACTED_TOKEN] vercel project ls

# Interactive login:
vercel login
```

## Common Gotchas
- v5 file API returns `{"error": "v5 of this endpoint has been disabled"}` — always use v8
- Env vars API needs `--project <name>` or prior `vercel link`
- Deployments list uses `dpl_` prefixed IDs
- Project IDs start with `prj_`
- `--name` flag on `vercel deploy` is deprecated but still works

## CLI Commands
```bash
# Deploy (non-interactive, production):
vercel deploy --yes --prod --token="$VERCEL_TOKEN" --name=project-name

# Inspect project:
vercel project inspect <name> --token="$VERCEL_TOKEN"

# List env vars:
vercel env ls --project <name> --token="$VERCEL_TOKEN"

# Link to existing project (for env vars etc):
cd project-dir && vercel link --token="$VERCEL_TOKEN"
```
