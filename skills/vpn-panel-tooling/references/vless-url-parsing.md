# VLESS URL Parsing & Conversion

## VLESS Link Format
```
vless://{uuid}@{server}:{port}?{params}#{remark}
```

## Required Params
`encryption=none&type=xhttp&security=reality&fp=chrome&sni={sni}&pbk={publicKey}&sid={shortId}&spx={spiderX}&path={path}&host={host}&mode=auto`

## Optional Params
`x_padding_bytes=0-0&extra={"mode":"auto","xPaddingBytes":"0-0"}`

## Python Parser
```python
import urllib.parse

def parse_vless(url):
    parsed = urllib.parse.urlparse(url)
    params = urllib.parse.parse_qs(parsed.query)
    return {
        'uuid': parsed.username,
        'server': parsed.hostname,
        'port': parsed.port,
        'network': params.get('type', ['tcp'])[0],
        'security': params.get('security', ['tls'])[0],
        'sni': params.get('sni', [''])[0],
        'fingerprint': params.get('fp', ['chrome'])[0],
        'publicKey': params.get('pbk', [''])[0],
        'shortId': params.get('sid', [''])[0],
        'spiderX': urllib.parse.unquote(params.get('spx', ['/'])[0]),
        'path': urllib.parse.unquote(params.get('path', ['/'])[0]),
        'host': params.get('host', [''])[0],
        'remark': urllib.parse.unquote(parsed.fragment or 'VPN'),
    }
```

## VLESS → Xray JSON Conversion
Convert parsed VLESS to full Xray config JSON:
- outbounds[0].settings.vnext[0]: server, port, users[0].id
- outbounds[0].streamSettings: network, security, xhttpSettings, realitySettings
- inbounds: SOCKS (10808) + HTTP (10809)
- dns: ["8.8.8.8", "1.1.1.1"]
- routing: DNS queries via proxy

## Subscription Link Decode
```bash
curl -s "https://panel/sub/{subId}" | base64 -d
```
Returns full VLESS URI. Check `#remark|📊100.00GB|⏳30D` suffix for expiry.

## Padding Bandwidth Impact
- `0-0`: 0% extra (fastest)
- `100-1000`: ~35% extra bandwidth
- `1000-5000`: ~50% extra bandwidth
