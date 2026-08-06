# Xray TLS Error Debugging

## Error Pattern
```
Failed to start: main: failed to load config files: [bin/config.json]
→ infra/conf: failed to build inbound config with tag in-XXXX-tcp
→ infra/conf: Failed to build TLS config
→ infra/conf: failed to parse certificate
→ infra/conf: both file and bytes are empty
```

The tag in the error (e.g., `in-8082-tcp`) identifies the problematic inbound.

## Root Causes
1. **`streamSettings` is `null`** — Xray defaults to TLS with empty certificates
2. **`security: "tls"` with empty certificate arrays** — `certificate: [], key: []`
3. **Stale config in DB** — Panel API shows `security: none` but DB has TLS settings

## Quick Fix: Update ALL Inbounds At Once
When you know the issue is TLS settings across multiple inbounds, skip the one-by-one approach and fix all at once:

```python
r = s.get(f"{base}/panel/api/inbounds/list", headers={"X-CSRF-Token": csrf})
for item in r.json()["obj"]:
    r2 = s.get(f"{base}/panel/api/inbounds/get/{item['id']}", headers={"X-CSRF-Token": csrf})
    full = r2.json()["obj"]
    stream = full.get("streamSettings") or {}
    
    needs_fix = False
    if stream.get("security") not in [None, "none"]:
        needs_fix = True
    if "tlsSettings" in stream or "realitySettings" in stream:
        needs_fix = True
    
    if needs_fix:
        network = stream.get("network", "tcp")
        if network not in ["tcp", "ws", "grpc", "h2", "httpupgrade"]:
            network = "tcp"
        
        new_stream = {"network": network, "security": "none"}
        # Preserve ws/grpc/h2 settings if they exist
        for key in ["wsSettings", "grpcSettings", "httpSettings"]:
            if key in stream:
                new_stream[key] = stream[key]
        
        update = {
            "id": item["id"], "remark": full.get("remark", ""),
            "enable": full.get("enable", True), "port": full.get("port"),
            "protocol": full.get("protocol", "vless"),
            "settings": full.get("settings", {}),
            "streamSettings": new_stream,
            "tag": item.get("tag", ""),
            "sniffing": full.get("sniffing", {"enabled": True, "destOverride": ["http", "tls"]})
        }
        s.post(f"{base}/panel/api/inbounds/update/{item['id']}",
            headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
            json=update)

# Restart once
s.post(f"{base}/panel/api/server/restartXrayService", headers={"X-CSRF-Token": csrf})
```

## Systematic Debugging: One-By-One (Python)

```python
import requests, json, time

s = requests.Session()
base = "https://PANEL_URL/managepanel"

# CSRF + Login
r = s.get(f"{base}/csrf-token")
csrf = r.json()["obj"]
r = s.post(f"{base}/login",
    headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
    json={"username": "admin", "password": "admin"})

# Step 1: Disable ALL inbounds
r = s.get(f"{base}/panel/api/inbounds/list", headers={"X-CSRF-Token": csrf})
for item in r.json()["obj"]:
    s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
        headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
        json={"enable": False})

# Step 2: Restart and confirm Xray runs
s.post(f"{base}/panel/api/server/restartXrayService", headers={"X-CSRF-Token": csrf})
time.sleep(3)
r = s.get(f"{base}/panel/api/server/status", headers={"X-CSRF-Token": csrf})
assert r.json()["obj"]["xray"]["state"] == "running"

# Step 3: Enable one by one, find culprit
r = s.get(f"{base}/panel/api/inbounds/list", headers={"X-CSRF-Token": csrf})
for item in r.json()["obj"]:
    s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
        headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
        json={"enable": True})
    s.post(f"{base}/panel/api/server/restartXrayService",
        headers={"X-CSRF-Token": csrf})
    time.sleep(2)
    r = s.get(f"{base}/panel/api/server/status", headers={"X-CSRF-Token": csrf})
    if r.json()["obj"]["xray"]["state"] == "error":
        print(f"CULPRIT: ID:{item['id']} {item.get('tag')}")
        s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
            headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
            json={"enable": False})
        s.post(f"{base}/panel/api/server/restartXrayService",
            headers={"X-CSRF-Token": csrf})
        time.sleep(2)

# Step 4: Fix the culprit's stream settings
r = s.get(f"{base}/panel/api/inbounds/get/{CULPRIT_ID}",
    headers={"X-CSRF-Token": csrf})
item = r.json()["obj"]
stream = {"network": "tcp", "security": "none"}
update = {
    "id": item["id"], "remark": item["remark"], "enable": True,
    "port": item["port"], "protocol": item["protocol"],
    "settings": item["settings"], "stream": stream,
    "tag": item["tag"], "sniffing": item["sniffing"]
}
s.post(f"{base}/panel/api/inbounds/update/{item['id']}",
    headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
    json=update)

# Step 5: Re-enable and verify
s.post(f"{base}/panel/api/inbounds/setEnable/{item['id']}",
    headers={"X-CSRF-Token": csrf, "Content-Type": "application/json"},
    json={"enable": True})
s.post(f"{base}/panel/api/server/restartXrayService",
    headers={"X-CSRF-Token": csrf})
```

## API Field Naming Quirk
| Endpoint | Stream field name |
|----------|------------------|
| `inbounds/list` | `stream` (may be `null` or string) |
| `inbounds/get/{id}` | `streamSettings` (camelCase, always object) |
| `inbounds/update/{id}` | ⚠️ **`streamSettings`** (NOT `stream`!) |

**3x-ui-multi v3.6.0**: Using `stream` in the update payload **silently fails** — API returns `{success: true}` but `streamSettings` remains `null`. Always use `streamSettings` as the key when updating.

Always handle both types when parsing:
```python
stream = item.get("stream") or item.get("streamSettings", {})
if isinstance(stream, str):
    stream = json.loads(stream)
```
