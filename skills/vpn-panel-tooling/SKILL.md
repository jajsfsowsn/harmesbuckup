---
name: vpn-panel-tooling
description: "Build XRay/3x-ui panel config tools and API wrappers."
---
# VPN Panel Tooling
Build tools that manage XRay-core VPN panels (3x-ui, Marzban). Covers config generation, API integration, and deployment.

## When to Use
- Config generators or management panels for XRay/3x-ui
- Automating inbound/client creation via panel API
- Reality keypair, shortId, or VLESS link generation

## Core Techniques
### Reality Keypair (x25519)
Use @noble/curves (Node.js crypto needs fragile DER parsing for x25519):
```javascript
const { x25519 } = require('@noble/curves/ed25519');
const privateKey = x25519.utils.randomPrivateKey();
const publicKey = x25519.getPublicKey(privateKey);
// base64 encode both — raw 32-byte keys, NOT PEM
```

### 3x-ui API
- Login: POST /login with form-encoded credentials → session cookie
- Add inbound: POST /panel/inbound/add with JSON + cookie
- ⚠️ settings, streamSettings, sniffing are JSON strings, not objects
- Sub link: http://{host}/sub/{subId} (no port on Railway)
- React-based forks (v3.4.2+) use `/managepanel/` base path: login at `/managepanel/`, API at `/managepanel/panel/api/...`

### VLESS Share Link
vless://{uuid}@{host}:8080?type=xhttp&security=reality&sni=www.samsung.com&fp=chrome&pbk={pubKey}&sid={shortId}&path={path}&spx=%2F&host={host}&encryption=none#{remark}

## Config Fields
**Fixed:** protocol=vless, port=8080, network=xhttp, security=reality, sni=www.samsung.com:443, fp=chrome, totalGB=107374182400, email=Mvpn

**Auto-gen:** keypair, shortIds, UUID, subId, xhttp path, expiryTime=now+30d

**User input:** config name, TCP proxy (host:port → dest + port)

**From deploy:** xhttp host = Railway hostname, externalProxy from TCP proxy

**xPaddingBytes options:**
- `0-0` — No padding (fastest, least secure, no extra bandwidth)
- `100-1000` — Medium padding (balanced)
- `1000-5000` — Heavy padding (most secure, ~35% extra bandwidth)
⚠️ `0-0` = fastest but traffic is identifiable by DPI. User chose `0-0` for speed.

## Deployment Pipeline (Vercel + Railway + 3x-ui)
Full automated VPN panel deployer: Vercel frontend → Railway backend → 3x-ui panel.

### Architecture
```
Vercel (frontend + API routes)
  ├── api/connect.js    — Verify GitHub/Railway tokens, fork repo
  ├── api/deploy.js     — Create Railway project, deploy from GitHub
  ├── api/create-inbound.js — Login panel, generate keys, create inbound
  └── api/tcp.js        — Test TCP proxy connectivity
Railway (hosting)
  └── 3x-ui-Upgrade (forked from mehrdadvpn/3x-ui-new)
```

### Vercel File Retrieval API
⚠️ v5 is **disabled**. Always use v8:
```
GET https://api.vercel.com/v8/now/deployments/{deployId}/files/{uid}
Header: Authorization: Bearer {VERCEL_TOKEN}
```
Response: `{"data": "<base64-encoded file content>"}` — must decode with `base64.b64decode()`.

### 3x-ui API Variants
The panel API path varies by version. Two known formats:

**Format A** (older/newer panels):
```
POST /panel/inbound/add          ← JSON body
POST /panel/inbound/del          ← JSON body { "id": 123 }
```

**Format B** (some forks):
```
POST /panel/api/inbounds/list/slim   ← GET, returns array
POST /panel/api/inbounds/del/{id}    ← POST, form-encoded empty body
POST /panel/inbound/add              ← POST, form-encoded body (URLSearchParams)
```
⚠️ Format B uses **form-encoded** body with `body.append()` for each field, NOT JSON.

### VLESS Link Format (XHTTP + Reality)
Two variants exist:

**Standard:**
```
vless://{uuid}@{host}:8080?type=xhttp&encryption=none
  &path={path}&host={panelHost}&mode=auto
  &x_padding_bytes=100-1000
  &extra={"mode":"auto","xPaddingBytes":"100-1000"}
  &security=reality&pbk={pubKey}&fp=chrome
  &sni=www.samsung.com&sid={shortId}&spx=%2F
  #{remark}
```
The `extra` param duplicates `mode` + `xPaddingBytes` as JSON. Some clients need it, some don't.

### TCP Proxy Troubleshooting
When config looks correct but connection fails:
1. **Test TCP reachability:** `bash -c 'echo "" > /dev/tcp/{host}/{port}'` — OPEN/CLOSED
2. **Check Reality keypair match:** private key on panel must equal the one generated for the public key in the link
3. **Check shortIds match:** `sid=` in link must be in panel's `shortIds` array
4. **Check xhttp path match:** `path=` in link must equal panel's `xhttpSettings.path`
5. **Check xhttp host match:** `host=` in link must equal panel's `xhttpSettings.host`
6. Both TCP proxies being "OPEN" does NOT mean config is correct — keys/IDs must also match

### Railway TCP Proxy
Railway TCP proxy format: `{name}.proxy.rlwy.net:{port}`
- Strip port for `externalProxy.dest`
- Use raw port number for `externalProxy.port`
- TCP proxy forwards raw traffic to the panel's inbound port (usually 8080)

## Vercel CLI Deployment
```bash
# Deploy to production (non-interactive):
cd src/
vercel deploy --yes --prod --token="$VERCEL_TOKEN" --name=project-name
# ⚠️ --name flag is deprecated but still works; project auto-links if vercel.json exists

# Inspect project:
vercel project inspect <name> --token="$VERCEL_TOKEN"

# List env vars (needs --project or prior vercel link):
vercel env ls --project <name> --token="$VERCEL_TOKEN"
```

## Post-Deploy Auto-Fill Pattern
After Railway deploy returns `panelUrl`, auto-fill config builder with clean base URL:
```javascript
const baseUrl = r.panelUrl.replace(/\\/$/, '').replace(/https?:\\/\\//, '');
const pUrl = 'https://' + baseUrl;
document.getElementById('cfgPanelUrl').value = pUrl;
```
Use `https://` + base domain only — no `/managepanel`, no `:3000` port suffix. User correction: "آدرس پنل رو بدون /managepanel:3000".

## Dark Theme CSS Patterns
When building dark-themed UIs for VPN tools, use muted colors:
```css
/* Dark theme variables */
body.dark {
  --bg: #0a0d12;           /* Very dark background */
  --bg-2: #080b0f;         /* Slightly darker */
  --fg: #d0ccc7;           /* Muted text (not pure white) */
  --muted: #6b7179;        /* Dimmed text */
  --glass: rgba(255,255,255,.03);      /* Very subtle glass */
  --glass-brd: rgba(255,255,255,.06);  /* Barely visible borders */
}

/* Dark theme elements - keep opacity LOW */
body.dark .orb { opacity: .2; }           /* Background orbs: 20% max */
body.dark .glass { box-shadow: inset 0 1px 0 rgba(255,255,255,.05), 0 20px 50px -20px rgba(0,0,0,.8); }
body.dark .glass::before { background: linear-gradient(160deg, rgba(255,255,255,.04), transparent 40%); }
body.dark .inp { background: rgba(255,255,255,.03); border: 1px solid rgba(255,255,255,.05); }
body.dark .btn-primary { box-shadow: 0 2px 12px rgba(225,90,76,.2); }
body.dark .sn { box-shadow: 0 2px 10px rgba(225,90,76,.15); }
body.dark .link-row { background: rgba(255,255,255,.02); border: 1px solid rgba(255,255,255,.04); }
body.dark .info-box { background: rgba(225,90,76,.04); border: 1px solid rgba(225,90,76,.1); }
body.dark .result-card { background: rgba(255,255,255,.02); border: 1px solid rgba(255,255,255,.04); }
```
User feedback: "حالت شب بجز رنگ متن ها رنگ چیزهای دیگه خیلی روشن" — non-text elements were too bright.

## Collapsible Guide Pattern
Add step-by-step guides next to form fields using collapse components:
```html
<button onclick="toggleCollapse('guideId')" style="width:100%;display:flex;align-items:center;justify-content:space-between;padding:8px 12px;margin-bottom:10px;border-radius:10px;font-size:11px;font-weight:600;background:rgba(225,90,76,.08);border:1px solid rgba(225,90,76,.15);cursor:pointer;color:var(--fg)">
  <div style="display:flex;align-items:center;gap:6px"><i class="fas fa-book-open" style="color:var(--coral);font-size:12px"></i>📖 راهنما</div>
  <i class="fas fa-chevron-down collapse-arrow" id="guideIdArrow" style="font-size:10px"></i>
</button>
<div class="collapse-content" id="guideId">
  <div style="padding:10px 12px;margin-bottom:10px;border-radius:10px;font-size:10px;line-height:2;background:rgba(225,90,76,.06);border:1px solid rgba(225,90,76,.12)">
    <p>۱. مرحله اول...</p>
    <p>۲. مرحله دوم...</p>
  </div>
</div>
```

## Communication Style
This user (Mehrdad) communicates in Persian and prefers:
- **Action-first:** Do the work, show results. Don't explain what you're about to do before doing it.
- **Autonomous execution:** When user says "خودت انجام بده" (do it yourself) or "خودت نمیتونی؟" (can't you do it?), they want YOU to complete the task — not suggest alternatives or ask them to do it. Never respond to "do this" with "you do this step, then that step".
- **Concise output:** Bullet points > paragraphs. Show the result, not the process.
- **No hand-holding:** If a tool works, just use it. Don't ask "should I proceed?".
- **No repeated failures:** If something fails 2+ times, try a completely different approach — don't retry the same thing.
- **Frustration signals:** "اوسکول", "چرا کار نمیکنی", "بکن دیگه", "انجام بده خودت" = user wants action NOW.
- Persian abbreviations: "ورسل" = Vercel, "رلوی" = Railway — clarify if ambiguous.

## Telegram Config Distribution
Distribute VPN configs to users via a Telegram channel. Pin compiled config lists so users always find them at the top.

### Channel Discovery
Find channel chat IDs from Hermes channel directory (`~/.hermes/channel_directory.json`):
```python
import json, os
with open(os.path.expanduser('~/.hermes/channel_directory.json')) as f:
    directory = json.load(f)
for ch in directory['platforms']['telegram']:
    if ch['type'] == 'channel':
        print(f"{ch['name']}: {ch['id']}")  # e.g. "-1004347094306"
```

### Bot Token
Read from `~/.hermes/.env` (terminal output redacts it):
```python
bot_token = None
with open(os.path.expanduser('~/.hermes/.env')) as f:
    for line in f:
        if line.strip().startswith('TELEGRAM_BOT_TOKEN='):
            bot_token = line.strip().split('=', 1)[1]
            break
```

### Send + Pin (Python stdlib only)
```python
import json, urllib.request
API_BASE = f"https://api.telegram.org/bot{bot_token}"

def telegram_api(method, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{API_BASE}/{method}", data=data,
                                headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req).read())

# Send message
resp = telegram_api("sendMessage", {
    "chat_id": CHANNEL_ID, "text": message_text,
    "disable_web_page_preview": True
})
msg_id = resp["result"]["message_id"]

# Pin it
telegram_api("pinChatMessage", {
    "chat_id": CHANNEL_ID, "message_id": msg_id,
    "disable_notification": False
})
```

### Message Formatting Pattern
When compiling multiple configs into one pinned message, use this structure:
```
🔒 راهنمای اتصال کانفیگ‌ها

━━━━━━━━━━━━━━━━━━━━━━━

🔹 کانفیگ N — 🏳️ Country
📊 Volume | ⏳ Duration
⏱ باقی‌مانده: ~XGB

vless://uuid@host:port?params...#remark

━━━━━━━━━━━━━━━━━━━━━━━

📋 نحوه استفاده:
1️⃣ لینک vless رو کپی کنید
2️⃣ در اپ V2rayNG / Nekobox وارد کنید
3️⃣ connect بزنید ✅

⚠️ نکات مهم:
• هر کانفیگ فقط برای یک نفر
• برای پشتیبانی به @MehrdadVpn پیام بدید
```
See `references/telegram-distribution.md` for the full pin script template.

## Debugging Techniques
### Decode Subscription Link
```bash
curl -s "https://panel/sub/{subId}" | base64 -d
```
Returns full VLESS URI. Check `#remark|📊100.00GB|⏳30D` suffix for expiry status.

### Check Panel Inbounds via API
Login → GET `/panel/api/inbounds/list/slim` → inspect clients array for `expiryTime`, `enable`, `totalGB` values.

## Railway TCP Proxy Creation Tutorial
When guiding users to create a TCP proxy on Railway, use this collapsible 9-step tutorial. Extract the project name dynamically from the deployed panel URL.

### Step Content
```
۱. روی Settings پروژه کلیک کنید
۲. پروژه‌تون رو انتخاب کنید — اسم پروژه: {extracted from URL}
۳. به آخرین تب Settings برید
۴. در قسمت Networking روی دکمه +TCP Proxy کلیک کنید
۵. در کادر باز شده پورت 8080 را وارد کنید و Add Proxy را بزنید
۶. سایت از شما میخواد پروژه رو Deploy کنید — روی گزینه Deploy کلیک کنید
   💡 پیشنهاد: در صورت نیاز همزمان سرور رو هم در تب Scale تغییر بدید و بعد Deploy کنید
۷. به تب Deployments برید و صبر کنید تا تمامی تغییرات اعمال شود
۸. صبر کنید تا پروژه‌های آبی رنگ سبز رنگ بشوند
۹. سپس TCP Proxy رو کپی کنید و به اینجا برگردید و تست کنید
```

### Project Name Extraction
```javascript
const projectName = r.panelUrl ? r.panelUrl.replace(/https?:\/\//, '').split('.')[0] : '';
document.getElementById('tcpProjName').textContent = projectName;
```

## Config Result Display Preference
After creating a VPN config, show **only the subscription link** with copy + open buttons. Do NOT display:
- Raw VLESS config
- Client name
- Expiry/volume details (keep minimal: just "حجم: 100GB | مدت: ۳۰ روز")

```html
<div class="result-card" style="text-align:center">
  <p>🔗 لینک سابسکریپشن</p>
  <p class="mono" id="cfgSubUrl">-</p>
  <div style="display:flex;gap:8px;justify-content:center">
    <button onclick="cp('cfgSubUrl')">📋 کپی</button>
    <button onclick="window.open(document.getElementById('cfgSubUrl').textContent)">🔗 باز کردن</button>
  </div>
</div>
```

## Vercel Source Modify & Redeploy Workflow
When modifying an existing Vercel project without the source code locally:

### 1. Download source from latest deployment
```bash
# Get deploy ID
DEPLOY_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v6/deployments?projectId=$PID&limit=1" | python3 -c "import json,sys;print(json.load(sys.stdin)['deployments'][0]['id'])")

# Get file tree
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v8/now/deployments/$DEPLOY_ID/files" 

# Download each file (v8 API, base64 encoded)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v8/now/deployments/$DEPLOY_ID/files/{uid}" | python3 -c "import json,sys,base64;print(base64.b64decode(json.load(sys.stdin)['data']).decode())" > filename
```

### 2. Modify locally, then deploy
```bash
cd project/src/
vercel deploy --yes --prod --token="$TOKEN"
```

## NapsterNetV (.npvt) Config Format
NapsterNetV is an Xray/V2Ray client for Android/iOS that exports configs in an encrypted `.npvt` format.

### Format Structure
```
NPVT1\n
{base64-part-1},{base64-part-2},{base64-part-3}
```
- **Part 1** (~24 chars): Encryption key material (17 bytes decoded)
- **Part 2** (~12K chars): Main encrypted config payload (9K+ bytes decoded)
- **Part 3** (~300 chars): Supplementary data (234 bytes decoded)

### Encryption
Uses **White-Box AES CTR mode** — keys embedded in large lookup tables (LUTs) to resist reverse engineering. NOT standard AES — cannot decrypt with normal crypto libraries.

### Decoder
PHP decoder available: `github.com/Nimadark/napsternetv-config-decoder`
```php
require_once 'napsternetv.php';
$tablesData = json_decode(file_get_contents('tables.json'), true);
$wbTables = new WhiteboxTables($tablesData['nr'], $tablesData['xor'], $tablesData['tyboxes'], $tablesData['tboxesLast'], $tablesData['mbl']);
$wbaes = new WBAESCTR($wbTables);
$importer = new ConfigImporter($wbaes);
$result = $importer->importConfig(file_get_contents('config.npvt'));
```

### Decoded JSON Structure
Once decrypted, the config is a standard Xray JSON with:
- `outbounds[0]`: VLESS/VMess/Trojan config with `streamSettings`
- `inbounds`: Local SOCKS proxy (port 10808)
- `dns`: DNS servers configuration
- `routing`: Traffic routing rules
- `remarks`: Display name with emoji flags + stats (e.g. `🇳🇱Rofgha|📊100.00GB|⏳29D`)

### Converting NPVT → VLESS Link
Extract from decoded JSON: `outbounds[0].settings.vnext[0]` for server info, `outbounds[0].streamSettings` for transport/security. Build standard VLESS share link from these fields.

## User Preference: Send Backup Files
After completing changes to a project, the user expects a downloadable backup file (tar.gz). Proactively create and send it via MEDIA: path without being asked.

## Pitfalls
- **GitHub Actions: Use pre-built Xray binaries, NOT compilation** — Compiling Xray-core on GitHub Actions frequently fails because Go toolchain version doesn't match what Xray-core's go.mod requires. Error: "go: download go1.26: toolchain not available". Fix: download pre-built binaries from `github.com/XTLS/Xray-core/releases/latest/download/` (ARM64, x86_64, x86). Only compile locally if you control the Go version.
- **GitHub token needs `workflow` scope to upload workflow files** — Uploading `.github/workflows/build.yml` via API or git push fails without `workflow` scope. API returns 404 "Not Found"; git push says "refusing to allow a Personal Access Token to create or update workflow without `workflow` scope". Fix: create token at https://github.com/settings/tokens/new with BOTH `repo` AND `workflow` scopes checked. Different GitHub accounts may have different token permissions — verify scopes with `curl -I -H "Authorization: token $TOKEN" https://api.github.com/user | grep x-oauth-scopes`.
- **Different GitHub accounts = different tokens** — User may provide tokens for different accounts. Each token only works with repos under that account. If API returns 404, check which user the token belongs to: `curl -H "Authorization: token $TOKEN" https://api.github.com/user`.
- **`git init` defaults to `master`, not `main`** — GitHub expects `main`. After `git init`, run `git branch -m master main` before pushing. Error: "src refspec main does not match any".
- **3x-ui `expiryTime` MUST be in milliseconds** — `Date.now() + 30 * 24 * 60 * 60 * 1000` (NOT seconds: `Math.floor(Date.now()/1000 + ...)`). If client shows 0 days or immediate expiry, this is the cause. Panel stores ms internally.
- **Subscription link may show `⏳0D` even when client is valid** — The 3x-ui subscription generator sometimes fails to parse `expiryTime` correctly and displays `0D`. The client still works fine with correct expiry. This is a display bug in the panel, not an actual expiry issue. Don't waste time "fixing" it — verify expiry by checking the client in the panel UI directly.
- 3x-ui API needs JSON.stringify(settings) — raw objects cause silent 400s
- Railway sub URL has no port: http://{hostname}/sub/{id}
- x25519 raw base64 keys, NOT PEM (use @noble/curves, not node crypto)
- Port 22 often blocked in cloud — use HTTPS for git
- Vercel API v5 is deprecated — always use v8 for file retrieval
- 3x-ui API paths vary by fork version — test with `/panel/api/inbounds/list/slim` first
- Form-encoded vs JSON body varies by 3x-ui version — check which format the panel expects
- Vercel `--name` flag is deprecated — prefer project auto-linking via vercel.json
- Persian abbreviations: "ورسل" = Vercel, "رلوی" = Railway — clarify if ambiguous
- **Auto-fill fields MUST remain editable** — User said: "آدرس پنل هم خودکار پر بشه هم کاربر بتونه ادرس جدید بذاره" — never use `readonly` on auto-filled inputs
- **3x-ui login endpoint varies by fork** — could be `/login`, `/managepanel/login`, or `/managepanel/api/login` — test each one
- **CSRF tokens** — React-based 3x-ui forks (v3.4.2+) require CSRF token from `<meta name="csrf-token">` in login page HTML before login request
- **Xray Core cross-compilation needs matching Go version** — Xray-core's `go.mod` may require Go 1.23+ while system has 1.22. Error: "go: download go1.26: toolchain not available". Fix: use pre-built binaries from GitHub releases instead of compiling. See `references/android-vpn-app.md`
- **ARM32 binary often unavailable** — Latest Xray releases frequently drop ARM32 (armeabi-v7a). Covers ~99% of modern devices anyway (ARM64 + x86_64 + x86)
- **Gradle 8.0 + Java 21 = crash** — "Unsupported class file major version 65". Use Gradle 8.5+ for Java 21 support
- **`gradle/actions/setup-gradle@v3` IGNORES wrapper version** — It installs its own Gradle 9.x regardless of gradle-wrapper.properties. Causes "Cannot mutate the dependencies of configuration" error with older AGP. Fix: download Gradle directly via curl in workflow, add to PATH. See `references/android-vpn-app.md` for working workflow.
- **gradle-wrapper.jar from random repos is often corrupt** — Error: "no main manifest attribute" or "Invalid or corrupt jarfile". The jar from nicovince/gradle-wrapper (319K) looked valid but was corrupt. Only63KB jars from official Gradle distributions work. Fix: download from `services.gradle.org` or use direct Gradle install in CI.
- **AGP version must match Gradle version** — AGP 8.1.x requires Gradle 8.2+, AGP 7.4.x requires Gradle 7.6+. Error: "Minimum supported Gradle version is 8.2. Current version is 7.6.3". Pin both versions together.
- **AndroidManifest `@mipmap/ic_launcher` needs actual resource files** — AAPT error: "resource mipmap/ic_launcher not found". Must provide ic_launcher in mipmap-* dirs OR use built-in Android drawable: `@android:drawable/ic_menu_manage`. Fastest fix for CI builds.

## Reference Files
- `references/android-vpn-app.md` — Android VPN app project structure (Kotlin + Xray Core)
- `references/three-x-ui-api.md` — Full API endpoints and request/response formats
- `references/vercel-api.md` — Vercel API notes (v8 file retrieval, project management)
- `references/dark-theme-css.md` — Dark theme CSS patterns, opacity values, auto-fill rules
- `references/telegram-distribution.md` — Full script for sending + pinning VPN configs to Telegram channels
- `references/vless-url-parsing.md` — VLESS URL parsing, conversion to Xray JSON, padding bandwidth impact
- `references/npvt-format.md` — NapsterNetV encrypted config format details
- `templates/inbound.json` — Complete VLESS+XHTTP+Reality inbound template with placeholders
