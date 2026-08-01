# Fetch/XHR Override for Ourenus Sub Page

## Purpose
Inject into pre-built `ourenus/index.html` to make the React SPA work without the sub server (port 2096). Returns hardcoded VLESS config data instead of fetching from API.

## When to Use
- Sub server (port 2096) is not running
- `/sub/` page shows "خطای اتصال به سرور" error
- Want the full Ourenus UI without backend

## Complete Injection Script

```html
<script>
(function() {
  var info = {
    "username": "Mehrdad",
    "data_limit": 107374182400,
    "used_traffic": 21474836480,
    "expire": 1893456000,
    "subscription_url": "#",
    "links": ["vless://fb2b7f35-4e4d-4d43-a3e2-1365f87e4f31@sakura.proxy.rlwy.net:13955?encryption=none&extra=%7B%22mode%22%3A%22auto%22%2C%22xPaddingBytes%22%3A%220-0%22%7D&fp=chrome&host=heimdall-railway-production.up.railway.app&mode=auto&path=%2Fmehrdad&pbk=EURW7X-zNj0Xybtrigduckzsx_zqjZwwxfbq3kAbgEI&security=reality&sid=d31d0b&sni=www.samsung.com&spx=%2Ffb1664e67e529bb&type=xhttp&x_padding_bytes=0-0#Mehrdad-VPN"],
    "speedLimits": [],
    "connectionLimit": 0
  };
  var configs = info.links[info.links.length - 1];

  // Override XMLHttpRequest
  var _open = XMLHttpRequest.prototype.open;
  var _send = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(m, url) {
    this._url = url;
    return _open.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    var self = this, u = this._url || '';
    setTimeout(function() {
      if (u.includes('/info')) {
        Object.defineProperty(self, 'readyState', {get: function(){return 4}});
        Object.defineProperty(self, 'status', {get: function(){return 200}});
        Object.defineProperty(self, 'responseText', {get: function(){return JSON.stringify(info)}});
        if (self.onreadystatechange) self.onreadystatechange();
        if (self.onload) self.onload();
      } else if (u.includes('/configs')) {
        Object.defineProperty(self, 'readyState', {get: function(){return 4}});
        Object.defineProperty(self, 'status', {get: function(){return 200}});
        Object.defineProperty(self, 'responseText', {get: function(){return configs}});
        if (self.onreadystatechange) self.onreadystatechange();
        if (self.onload) self.onload();
      } else {
        _send.apply(self, arguments);
      }
    }, 0);
  };

  // Override fetch
  var _fetch = window.fetch;
  window.fetch = function(url, opts) {
    var u = typeof url === 'string' ? url : (url && url.url) || '';
    if (u.includes('/info'))
      return Promise.resolve(new Response(JSON.stringify(info), {status: 200, headers: {'Content-Type': 'application/json'}}));
    if (u.includes('/configs'))
      return Promise.resolve(new Response(configs, {status: 200, headers: {'Content-Type': 'text/plain'}}));
    return Promise.resolve(new Response('{}', {status: 200, headers: {'Content-Type': 'application/json'}}));
  };
})();
</script>
```

## Python Injection Script

```python
import json

config = "vless://YOUR_CONFIG_HERE"
info_data = {
    "username": "User",
    "data_limit": 107374182400,
    "used_traffic": 0,
    "expire": 1893456000,
    "subscription_url": "#",
    "links": [config],
    "speedLimits": [],
    "connectionLimit": 0
}

# Read the pre-built HTML
with open('/tmp/ourenus-original.html', 'r') as f:
    html = f.read()

# Inject before </head>
inject = f"""<script>
(function() {{
  var info = {json.dumps(info_data, ensure_ascii=False)};
  var configs = {json.dumps(config, ensure_ascii=False)};
  // ... (full override code from above)
}})();
</script>"""

html = html.replace('<head>', '<head>' + inject, 1)

with open('/data/workspace/sub-view.html', 'w') as f:
    f.write(html)
```

## Key Details

### `info` Object Fields
| Field | Type | Description |
|-------|------|-------------|
| `username` | string | Display name |
| `data_limit` | int | Total bytes (107374182400 = 100GB) |
| `used_traffic` | int | Used bytes |
| `expire` | int | Unix timestamp (1893456000 = 2030) |
| `subscription_url` | string | Sub link for button |
| `links` | string[] | Array of VLESS configs (use `links`, NOT `link`) |
| `speedLimits` | array | Speed limit info |
| `connectionLimit` | int | Max connections |

### Ourenus React App Behavior
- Reads `s.links[s.links.length - 1]` for the last config
- Reads `s.subscription_url` for the subscription link button
- Shows `s.username` in the header
- Shows usage bar from `s.used_traffic / s.data_limit * 100`
- Shows expiry from `s.expire`
- Configs are displayed in an accordion with copy buttons
- Each config link has a QR code generated

### Why Override Both XHR and Fetch
- Older browsers/libraries use `XMLHttpRequest`
- Newer React code uses `fetch`
- The Ourenus app tries `fetch` first, falls back to `XMLHttpRequest`
- Overriding only one leaves gaps where the other is used
- The React app's Axios library can use either depending on browser support

### Injection Position
Inject the script BEFORE the React bundle `<script type="module">` tag. The overrides must be in place before React initializes. `html.replace('<head>', '<head>' + inject, 1)` works because the `<head>` tag appears once at the start.
