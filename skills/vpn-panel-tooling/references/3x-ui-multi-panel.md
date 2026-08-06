# 3x-ui-multi Panel Reference

## Panel Info
- **URL**: `3x-ui-multi-production-0885.up.railway.app`
- **Version**: 3.6.0
- **Xray**: v26.7.28
- **Login**: admin/admin
- **Base path**: `/managepanel/`

## API Authentication
```python
import requests, json
s = requests.Session()
base = "https://3x-ui-multi-production-0885.up.railway.app/managepanel"

# Method 1: Form-encoded (simpler, no CSRF needed)
r = s.post(f"{base}/login", data={"username": "admin", "password": "admin"})

# Method 2: JSON with CSRF
r = s.get(f"{base}/csrf-token")
csrf = r.json()["obj"]
r = s.post(f"{base}/login", 
    headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
    json={"username": "admin", "password": "admin"})
```

## Inbounds (as of 2026-07-31)
| ID | Tag | Port | Network | Security |
|----|-----|------|---------|----------|
| 1 | direct-inbound | 8080 | tcp | none |
| 2 | in-8081-tcp | 8081 | tcp | none |
| 3 | in-8082-tcp | 8082 | tcp | none |
| 4 | in-8083-ws | 8083 | ws | none |
| 5 | fr | 8084 | tcp | none |
| 6 | se | 8085 | tcp | none |
| 7 | ch | 8086 | tcp | none |
| 8 | fi | 8087 | tcp | none |
| 9 | gb | 8088 | tcp | none |
| 10 | ro | 8090 | tcp | none |

## Critical API Quirks

### `streamSettings` vs `stream`
The3x-ui-multi v3.6.0 has a critical difference from other forks:
- `inbounds/list` returns `stream` field (often null)
- `inbounds/get/{id}` returns `streamSettings` field
- **Update endpoint ONLY works with `streamSettings`** — using `stream` silently fails

```python
# CORRECT ✅
update = {
    "id": 4,
    "streamSettings": {"network": "ws", "security": "none", ...}
}

# WRONG ❌ (silently fails)
update = {
    "id": 4, 
    "stream": {"network": "ws", "security": "none", ...}
}
```

### Verification After Update
Always verify settings were saved:
```python
r = s.get(f"{base}/panel/api/inbounds/get/4", headers={"X-CSRF-Token": csrf})
item = r.json()["obj"]
assert item.get("streamSettings") is not None, "Settings not saved!"
```

## Railway TLS Pattern
- Server inbound: `security: "none"` (Railway terminates TLS at edge)
- Client config: `security: "tls"` (client connects to Railway domain with TLS)
- Port 443 for client, actual inbound port (e.g. 8083) for internal routing

## Xray TLS Error Debugging
When Xray fails with "both file and bytes are empty":
1. Disable ALL inbounds via `setEnable/{id}` with `enable: false`
2. Restart Xray → should run
3. Enable one by one, restarting after each
4. The one that breaks Xray is the culprit (error message names the tag)
5. Fix its `streamSettings` to `security: "none"`
6. Continue until all are enabled and Xray runs

### Python Debugging Script
```python
import requests, json, time

s = requests.Session()
base = "https://DOMAIN/managepanel"

# CSRF + Login
r = s.get(f"{base}/csrf-token")
csrf = r.json()["obj"]
s.post(f"{base}/login", headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
    json={"username": "admin", "password": "admin"})

# Disable all inbounds
r = s.get(f"{base}/panel/api/inbounds/list", headers={"X-CSRF-Token": csrf})
for item in r.json()["obj"]:
    s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
        headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
        json={"enable": False})

# Restart
s.post(f"{base}/panel/api/server/restartXrayService", headers={"X-CSRF-Token": csrf})
time.sleep(3)

# Enable one by one
for item in r.json()["obj"]:
    s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
        headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
        json={"enable": True})
    s.post(f"{base}/panel/api/server/restartXrayService", headers={"X-CSRF-Token": csrf})
    time.sleep(2)
    
    status = s.get(f"{base}/panel/api/server/status", headers={"X-CSRF-Token": csrf})
    xray = status.json()["obj"]["xray"]
    
    if xray.get("state") == "error":
        print(f"BROKEN: {item.get('tag')}")
        s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
            headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
            json={"enable": False})
        s.post(f"{base}/panel/api/server/restartXrayService", headers={"X-CSRF-Token": csrf})
        time.sleep(2)
    else:
        print(f"OK: {item.get('tag')}")
```
