# 3x-ui / Heimdall API Reference

## ⚠️ API Path Variants
Two different API structures exist. Use the right one based on which fork you're targeting:

| Feature | Older 3x-ui / Format B | Heimdall v1.5.0 (sh7CBAC) |
|---------|----------------------|---------------------------|
| CSRF | `<meta>` tag in HTML | GET `/managepanel/csrf-token` → `{obj: token}` |
| Login | POST `/managepanel/api/login` | POST `/managepanel/login` |
| List inbounds | GET `/panel/api/inbounds/list/slim` | GET `/managepanel/panel/api/inbounds/list/slim` |
| Get inbound | — | GET `/managepanel/panel/api/inbounds/get/{id}` |
| Update inbound | POST `/panel/api/inbounds/update/{id}` | POST `/managepanel/panel/api/inbounds/update/{id}` |
| Server status | POST `/panel/api/server/getData` | GET `/managepanel/panel/api/server/status` |
| Restart Xray | POST `/panel/api/xray/restart` | POST `/managepanel/panel/api/server/restartXrayService` |
| Xray logs | POST `/panel/api/server/logs/{count}` | POST `/managepanel/panel/api/server/xraylogs/{count}` |
| OpenAPI spec | — | GET `/managepanel/panel/api/openapi.json` |

## Heimdall v1.5.0 Authentication Flow

```
POST /login
Content-Type: application/x-www-form-urlencoded

username=admin&password=secret
```

Response: Sets `session=xxx` cookie. Use this cookie for all subsequent requests.

## Add Inbound

```
POST /panel/inbound/add
Content-Type: application/json
Cookie: session=xxx
```

### Request Body Structure

```json
{
  "up": 0,
  "down": 0,
  "total": 0,
  "remark": "config-name",
  "enable": true,
  "expiryTime": 0,
  "listen": "",
  "port": 8080,
  "protocol": "vless",
  "settings": "<JSON string of client settings>",
  "streamSettings": "<JSON string of stream/reality settings>",
  "sniffing": "<JSON string of sniffing settings>",
  "tag": "in-8080-tcp",
  "allocate": {
    "strategy": "none",
    "refresh": 5,
    "concurrency": 3
  }
}
```

⚠️ **CRITICAL:** `settings`, `streamSettings`, and `sniffing` must be `JSON.stringify()`'d strings, NOT raw objects. Sending objects causes silent failures.

### Response

```json
{
  "success": true,
  "obj": { "id": 123 }
}
```

## Subscription Endpoint

```
GET http://{panel_host}/sub/{subId}
```

- On Railway: no port needed in URL
- Returns base64-encoded config for client import

## CSRF Token (React-based panels)

Newer 3x-ui forks (3x-ui-Upgrade, v3.4.2+) use a React frontend with CSRF protection:

```bash
# Step 1: Get CSRF token from login page HTML
CSRF=$(curl -s -c /tmp/cookies.txt \
  "https://panel.up.railway.app/managepanel/" \
  | grep -o 'name="csrf-token" content="[^"]*"' \
  | sed 's/.*content="//' | sed 's/"//')

# Step 2: Login with CSRF header
curl -s -b /tmp/cookies.txt -c /tmp/cookies.txt \
  -H "X-CSRF-Token: $CSRF" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  "https://panel.up.railway.app/managepanel/api/login"
```

⚠️ Login endpoint varies by fork: `/login`, `/managepanel/login`, `/managepanel/api/login`. Test each.

## Get Inbounds

```
GET /panel/inbounds
Cookie: session=xxx
```

## Delete Inbound

```
POST /panel/inbound/del
Content-Type: application/json
Cookie: session=xxx
Body: { "id": 123 }
```

## Format B: URLSearchParams (3x-ui-Upgrade fork)

Some forks (notably `3x-ui-Upgrade` / `mehrdadvpn/3x-ui-new`) use form-encoded bodies for inbound creation:

### List Inbounds (slim)
```
GET /panel/api/inbounds/list/slim
Cookie: session=xxx
X-CSRF-Token: {csrf}
X-Requested-With: XMLHttpRequest
```
Returns array of inbound objects (not wrapped in `{obj: [...]}`).

### Delete Inbound
```
POST /panel/api/inbounds/del/{id}
Cookie: session=xxx
X-CSRF-Token: {csrf}
Content-Type: application/x-www-form-urlencoded
Body: (empty)
```

### Add Inbound (form-encoded)
```
POST /panel/api/inbounds/add
Cookie: session=xxx
X-CSRF-Token: {csrf}
X-Requested-With: XMLHttpRequest
Content-Type: application/x-www-form-urlencoded
```

Use `URLSearchParams` — each field is a separate form field, NOT a JSON body:
```javascript
const body = new URLSearchParams();
body.append('listen', '');
body.append('port', '8080');
body.append('protocol', 'vless');
body.append('tag', configName);
body.append('remark', configName);
body.append('enable', 'true');
body.append('settings', JSON.stringify({...}));  // settings IS JSON string
body.append('streamSettings', JSON.stringify({...}));
body.append('sniffing', JSON.stringify({...}));
```

### Restart Xray
```
POST /panel/api/xray/restart
Cookie: session=xxx
X-CSRF-Token: {csrf}
Content-Type: application/x-www-form-urlencoded
Body: (empty)
```

## Subscription Link Display Quirk

The subscription endpoint returns base64-encoded VLESS config with metadata appended:
```
#configName|📊100.00GB|⏳30D
```

⚠️ The `⏳0D` display is a known bug — the panel's subscription generator sometimes fails to parse `expiryTime` and shows 0 days even when the client is valid for 30 days. **Don't chase this** — the client works correctly.

## Heimdall v1.5.0 Client Update Validation
When updating inbound with new client via Heimdall v1.5.0 API, strict type validation applies:

```python
# CORRECT
client = {
    "email": "default",
    "enable": True,
    "id": str(uuid.uuid4()),
    "flow": "",
    "limitIp": 0,
    "subId": "",
    "tgId": 0,           # MUST be int (0), NOT string ("")
    "totalGB": 0,
    "expiryTime": 0
}

# WRONG — will fail with "json: cannot unmarshal string into Go struct field Client.tgId of type int64"
client["tgId"] = ""  # ❌ string
client["port"] = "8080"  # ❌ string (must be int)
```

`settings`, `streamSettings`, `sniffing` can be dict objects (not JSON strings) — Heimdall v1.5.0 accepts both formats.
