# Telegram Config Distribution — Full Script Template

Complete Python script for sending and pinning VPN config compilations to a Telegram channel.

## Setup Requirements
- Bot token in `~/.hermes/.env` as `TELEGRAM_BOT_TOKEN=...`
- Bot must be an admin in the target channel (with "pin messages" permission)
- Channel ID from `~/.hermes/channel_directory.json`

## Full Script

```python
#!/usr/bin/env python3
"""Send and pin VPN configs to a Telegram channel."""
import json, os, urllib.request

# ─── Config ──────────────────────────────────────────────
CHANNEL_ID = "-100XXXXXXXXXX"  # from channel_directory.json

# ─── Bot Token ───────────────────────────────────────────
bot_token = None
with open(os.path.expanduser('~/.hermes/.env')) as f:
    for line in f:
        if line.strip().startswith('TELEGRAM_BOT_TOKEN='):
            bot_token = line.strip().split('=', 1)[1]
            break
assert bot_token, "TELEGRAM_BOT_TOKEN not found in ~/.hermes/.env"

API_BASE = f"https://api.telegram.org/bot{bot_token}"

# ─── Helper ──────────────────────────────────────────────
def telegram_api(method, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{API_BASE}/{method}",
        data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

# ─── Message Template ────────────────────────────────────
# Customize this for each config list
MESSAGE = """🔒 راهنمای اتصال کانفیگ‌ها

━━━━━━━━━━━━━━━━━━━━━━━

🔹 کانفیگ ۱ — 🏳️ Country
📊 100GB | ⏳ 30 روز

vless://UUID@HOST:PORT?params...#Remark

━━━━━━━━━━━━━━━━━━━━━━━

📋 نحوه استفاده:
1️⃣ لینک vless بالا رو کپی کنید
2️⃣ در اپ V2rayNG / Nekobox / Streisand وارد کنید
3️⃣ روی دکمه connect بزنید ✅

⚠️ نکات مهم:
• هر کانفیگ فقط برای یک نفر هست
• برای پشتیبانی به @MehrdadVpn پیام بدید"""

# ─── Send + Pin ──────────────────────────────────────────
print("📤 Sending message...")
result = telegram_api("sendMessage", {
    "chat_id": CHANNEL_ID,
    "text": MESSAGE,
    "disable_web_page_preview": True,
})

if result.get("ok"):
    msg_id = result["result"]["message_id"]
    print(f"✅ Sent! Message ID: {msg_id}")

    print("📌 Pinning...")
    pin = telegram_api("pinChatMessage", {
        "chat_id": CHANNEL_ID,
        "message_id": msg_id,
        "disable_notification": False,
    })
    if pin.get("ok"):
        print("✅ Pinned successfully!")
    else:
        print(f"❌ Pin failed: {pin}")
else:
    print(f"❌ Send failed: {result}")
```

## Key Points

1. **Token is redacted in terminal** — never visible in `terminal()` output. Read from file in Python.
2. **Channel IDs use `-100` prefix** — Telegram channel IDs start with `-100` (e.g., `-1004347094306`).
3. **Bot needs admin rights** — must be channel admin with "Pin Messages" permission.
4. **`disable_web_page_preview: true`** — prevents link previews from cluttering the pinned message.
5. **Write script to file, then run** — don't inline the full script in a terminal heredoc; write with `write_file` and execute with `terminal`.
6. **Unpin first if re-pinning** — if updating an existing pinned message, unpin the old one first:
   ```python
   telegram_api("unpinChatMessage", {"chat_id": CHANNEL_ID})
   ```

## Finding Configs in Conversation History

When user shares multiple configs across messages, compile them into one pinned message:
1. Extract each `vless://...` link from the conversation
2. Parse the link to identify: country flag, config name/number, server host, port
3. Note usage status (from screenshots: GB used, GB remaining)
4. Order by relevance (most available bandwidth first, or by config number)
5. Format into the template above
