# NapsterNetV (.npvt) Format Reference

## File Structure
- Header: `NPVT1\n` (6 bytes)
- Body: 3 comma-separated Base64-encoded segments
- Total size: ~12KB typical

## Segment Breakdown
| Segment | Typical Size | Content |
|---------|-------------|---------|
| Part 1 | 24 chars (17 bytes) | Key material / IV |
| Part 2 | 12,280 chars (9,210 bytes) | Encrypted config payload |
| Part 3 | 312 chars (234 bytes) | Metadata / checksum |

## Encryption: White-Box AES CTR
- Keys are NOT extractable — embedded in mathematical lookup tables
- Tables: `nr`, `xor`, `tyboxes`, `tboxesLast`, `mbl`
- Cannot use standard AES libraries — need the specific WB implementation
- Counter mode: 32-bit unsigned shifting, Big-Endian byte order

## Decoder Resources
- **GitHub:** `github.com/Nimadark/napsternetv-config-decoder`
- **Files:** `napsternetv.php` (core), `tables.json` (WB tables), `convert.php` (runner)
- **Language:** PHP (standalone, no dependencies)
- **Dev:** `@nimadark045` on Telegram

## Decoded JSON Schema (Xray core format)
```json
{
  "remarks": "flag+name|📊100.00GB|⏳29D",
  "log": {"loglevel": "warning"},
  "inbounds": [{"tag":"socks","port":10808,"protocol":"socks",...}],
  "outbounds": [{
    "tag": "proxy",
    "protocol": "vless",
    "settings": {"vnext": [{"address":"...","port":...,"users":[{"id":"uuid"}]}]},
    "streamSettings": {
      "network": "xhttp",
      "security": "reality",
      "xhttpSettings": {"path":"/...","host":"...","mode":"auto"},
      "realitySettings": {"serverName":"...","fingerprint":"chrome","publicKey":"...","shortId":"...","spiderX":"/..."}
    }
  }],
  "dns": {"servers": ["1.1.1.1"], "hosts": {...}},
  "routing": {...}
}
```

## Converting Decoded JSON → VLESS Share Link
From `outbounds[0]`:
- UUID: `settings.vnext[0].users[0].id`
- Server: `settings.vnext[0].address`
- Port: `settings.vnext[0].port`
- Network: `streamSettings.network`
- Security: `streamSettings.security`
- PBK: `streamSettings.realitySettings.publicKey`
- SID: `streamSettings.realitySettings.shortId`
- FP: `streamSettings.realitySettings.fingerprint`
- SNI: `streamSettings.realitySettings.serverName`
- Path: `streamSettings.xhttpSettings.path`
- Host: `streamSettings.xhttpSettings.host`
- SPX: `streamSettings.realitySettings.spiderX`

## Converting VLESS Link → NPVT JSON

### Parsing VLESS Link
```
vless://{uuid}@{server}:{port}?encryption=none
  &extra={"mode":"auto","xPaddingBytes":"100-1000"}
  &fp={fingerprint}&host={xhttpHost}&mode=auto
  &path={xhttpPath}&pbk={publicKey}&security=reality
  &sid={shortId}&sni={serverName}&spx={spiderX}
  &type=xhttp&x_padding_bytes=100-1000
  #{remark}
```

### JSON Conversion Logic
```python
import urllib.parse

parsed = urllib.parse.urlparse(vless_url)
params = urllib.parse.parse_qs(parsed.query)

config = {
    "remarks": f"🇳🇱{remark}|📊100.00GB|⏳30D",
    "outbounds": [{
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
            "vnext": [{
                "address": parsed.hostname,
                "port": parsed.port,
                "users": [{"id": parsed.username, "level": 8, "encryption": "none"}]
            }]
        },
        "streamSettings": {
            "network": "xhttp",
            "security": "reality",
            "xhttpSettings": {
                "path": params['path'][0],
                "host": params['host'][0],
                "mode": "auto",
                "extra": {"mode": "auto", "xPaddingBytes": "100-1000"}
            },
            "realitySettings": {
                "serverName": params['sni'][0],
                "fingerprint": params['fp'][0],
                "publicKey": params['pbk'][0],
                "shortId": params['sid'][0],
                "spiderX": urllib.parse.unquote(params['spx'][0])
            }
        }
    }]
}
```

## XHTTP Extra Parameter
The `extra` field duplicates mode and xPaddingBytes as JSON:
```json
{"mode": "auto", "xPaddingBytes": "100-1000"}
```
Some clients need this, some don't. Include for compatibility.

## Padding Bytes Explained
- **Purpose**: Obfuscate traffic patterns to prevent DPI detection
- **Format**: `"100-1000"` means random padding between 100-1000 bytes per packet
- **Trade-off**: ~1-3% speed reduction for significantly better stealth
- **Impact**: Both download and upload affected equally
- **Options**:
  - `0-0` — No padding (fastest, ~0% overhead, but traffic is identifiable)
  - `100-1000` — Medium padding (~35% extra bandwidth, good stealth)
  - `1000-5000` — Heavy padding (~50%+ extra bandwidth, best stealth)
- **Bandwidth impact** (100MB file):
  - `0-0`: 100MB transferred
  - `100-1000`: ~135MB transferred (35MB extra)
  - `1000-5000`: ~150MB+ transferred
- **User preference**: `0-0` chosen for maximum speed

## ⚠️ Encryption Limitation
Cannot create valid encrypted NPVT files without:
1. White-Box AES tables from the NapsterNetV app
2. The specific LUT (lookup table) files
3. App-specific key material

JSON configs can be created, but encryption requires app extraction.

## Known Clients Using This Format
- NapsterNetV (Android/iOS)
- Npv Tunnel (variant)
