# Android VPN App with Xray Core

## Project Structure
```
VpnApp/
├── app/src/main/
│   ├── AndroidManifest.xml          ← VPN permission + service declaration
│   ├── assets/xray                  ← Compiled Xray binary (ARM64/ARM32)
│   ├── java/com/rofgha/vpn/
│   │   ├── MainActivity.kt          ← UI: config input + connect/disconnect
│   │   ├── VpnService.kt            ← Android VpnService + Xray lifecycle
│   │   ├── VlessParser.kt           ← Parse vless:// URI → VlessConfig data class
│   │   ├── XrayCore.kt              ← Copy binary, chmod, ProcessBuilder start
│   │   └── XrayConfigGenerator.kt   ← VlessConfig → Xray JSON config
│   └── res/
│       ├── layout/activity_main.xml
│       ├── values/colors.xml, strings.xml, themes.xml
│       └── drawable/                 ← Vector icons + shape backgrounds
├── compile-xray.sh                   ← Cross-compile Xray for Android ARM
├── build.gradle, settings.gradle, gradle.properties
└── README.md
```

## Key Classes

### VlessParser.kt
Parses `vless://uuid@server:port?params#remark` → `VlessConfig` data class.
Extracts: uuid, server, port, network, security, sni, fingerprint, publicKey, shortId, spiderX, path, host, remark.
Uses `android.net.Uri.parse()` + `URLDecoder.decode()` for encoded params.

### VpnService.kt
- Extends `android.net.VpnService`
- `Builder()` sets: address 10.0.0.2/32, route 0.0.0.0/0, DNS 8.8.8.8, MTU 1500
- Calls `builder.establish()` → `ParcelFileDescriptor`
- Starts Xray in foreground service with notification
- Stop action via intent: `intent.action = "STOP"`

### XrayCore.kt
- Copies `xray` binary from assets to `filesDir`
- `chmod 755` then `ProcessBuilder("xray", "run", "-c", configPath)`
- Reads stdout in background thread for logging
- Stop: `process.destroy()`

### XrayConfigGenerator.kt
- Takes `VlessConfig` → generates full Xray JSON
- Inbounds: SOCKS (10808) + HTTP (10809)
- Outbounds: proxy (vless) + direct (freedom) + block (blackhole)
- StreamSettings: network=xhttp, security=reality, xPaddingBytes=0-0
- DNS: 8.8.8.8, 1.1.1.1
- Routing: DNS via proxy

## Xray Core — Pre-built Binaries (Recommended)
Faster than cross-compiling. Download from GitHub releases:
```bash
# ARM64 (most modern phones)
wget "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
# x86_64 (emulators)
wget "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
# x86 (old devices)
wget "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-32.zip"
# ARM32 — often NOT available in latest release (deprecated architecture)
```
Unzip, rename to `xray-arm64`, `xray-x64`, `xray-x86`, place in `app/src/main/assets/`.

## Xray Core Cross-Compilation (Alternative)
⚠️ Requires matching Go version — Xray-core may need newer Go than installed.
```bash
# Requires: Go 1.23+, Git
git clone https://github.com/XTLS/Xray-core.git
cd Xray-core
GOOS=android GOARCH=arm64 CGO_ENABLED=0 \
  go build -o ../app/src/main/assets/xray \
  -trimpath -ldflags="-s -w -buildid=" ./main
```
⚠️ Use `CGO_ENABLED=0` (not 1) for static binary. `CGO_ENABLED=1` requires Android NDK cross-compiler.

## Universal APK — Architecture Detection
XrayCore.kt auto-detects device ABI and picks the right binary:
```kotlin
private fun getBinaryName(): String {
    val arch = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
    return when {
        arch.contains("arm64") || arch.contains("aarch64") -> "xray-arm64"
        arch.contains("arm") -> "xray-arm32"
        arch.contains("x86_64") || arch.contains("amd64") -> "xray-x64"
        arch.contains("x86") || arch.contains("i686") -> "xray-x86"
        else -> "xray-arm64"
    }
}
```
build.gradle must include all ABIs: `abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'`

## Build Environment (Headless Linux)
```bash
# Java 21 (required for Gradle 8.5)
apt-get install -y default-jdk

# Go 1.23+
wget https://go.dev/dl/go1.23.0.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz

# Android SDK
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
# Extract to /opt/android-sdk/cmdline-tools/latest/
sdkmanager "platforms;android-34" "build-tools;34.0.0"

# Gradle 8.5
wget https://services.gradle.org/distributions/gradle-8.5-bin.zip
```

### Common Build Errors
- **"Unsupported class file major version 65"** → Gradle version too old for Java 21. Use Gradle 8.5+
- **"repository added by build file"** → Use `repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)` in settings.gradle
- **Go "toolchain not available"** → Xray-core needs newer Go. Update Go or use pre-built binaries
- **Gradle daemon OOM** → Use `--no-daemon` + `-Xmx768m`, or better: use GitHub Actions

## AndroidManifest.xml Key Parts
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<service android:name=".VpnService"
         android:permission="android.permission.BIND_VPN_SERVICE">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
</service>
```

## Build.gradle Key Config
```groovy
android {
    ndk { abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86' }
    sourceSets { main { jniLibs.srcDirs = ['libs'] } }
}
dependencies {
    implementation 'com.google.code.gson:gson:2.10.1'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3'
}
```

## VpnService Foreground Notification
Required for Android 8+ to keep VPN alive:
- Create NotificationChannel (IMPORTANCE_LOW)
- `startForeground(NOTIFICATION_ID, notification)`
- Notification: "Rofgha VPN — متصل به VPN"

## GitHub Actions (Recommended Build Method)
Build APK on GitHub's infrastructure — no local tools needed.

### ⭐ Recommended: Pre-built Binaries + Direct Gradle Install (Most Reliable)
```yaml
name: Build Rofgha VPN
on:
  push:
    branches: [ main ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-java@v4
      with:
        java-version: "17"
        distribution: "temurin"
    - name: Download Xray binaries
      run: |
        mkdir -p app/src/main/assets
        cd app/src/main/assets
        curl -sL "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip" -o arm64.zip
        unzip -q arm64.zip && mv xray xray-arm64 && rm arm64.zip
        curl -sL "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip" -o x64.zip
        unzip -q x64.zip && mv xray xray-x64 && rm x64.zip
        curl -sL "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-32.zip" -o x86.zip
        unzip -q x86.zip && mv xray xray-x86 && rm x86.zip
        chmod +x xray-*
    - name: Install Gradle 8.2
      run: |
        curl -sL "https://services.gradle.org/distributions/gradle-8.2-bin.zip" -o /tmp/gradle.zip
        sudo unzip -q -o /tmp/gradle.zip -d /opt/
        echo "/opt/gradle-8.2/bin" >> $GITHUB_PATH
    - name: Build APK
      run: gradle assembleDebug --no-daemon
    - uses: actions/upload-artifact@v4
      with:
        name: RofghaVPN
        path: app/build/outputs/apk/debug/app-debug.apk
```
⚠️ **DO NOT use `gradle/actions/setup-gradle@v3`** — it ignores wrapper version and uses its own Gradle 9.x. Also **DO NOT use gradlew** if gradle-wrapper.jar is not verified — random repos host corrupt jars.

### ⚠️ Alternative: Compile Xray (May Fail)
Compiling often fails due to Go version mismatch:
```yaml
    - uses: actions/setup-go@v5
      with: { go-version: '1.22.0' }  # MUST pin exact version
    - run: git clone --depth 1 https://github.com/XTLS/Xray-core.git
    - run: |
        cd Xray-core
        GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -o ../app/src/main/assets/xray-arm64 -trimpath -ldflags="-s -w" ./main
```
⚠️ Xray-core's go.mod may require Go 1.23+ while setup-go provides 1.22. Error: "go: download go1.26: toolchain not available".

APK available in Actions → Artifacts after build completes.

## Headless Build Constraints
⚠️ Building on memory-constrained servers (Railway, small VMs) often fails:
- Gradle daemon OOM kills — use `--no-daemon` + `-Xmx768m`
- Still may fail — prefer GitHub Actions or local machine
- If build daemon crashes: `pkill -f gradle` before retry
- Best approach: avoid local builds entirely, use GitHub Actions

## GitHub Actions Workflow Upload Pitfall
⚠️ Pushing `.github/workflows/build.yml` requires token with `workflow` scope:
- **Git push error:** "refusing to allow a Personal Access Token to create or update workflow `.github/workflows/build.yml` without `workflow` scope"
- **API error:** Returns 404 "Not Found" (not actually missing — it's a scope issue)
- **Fix:** Create token at `https://github.com/settings/tokens/new` with BOTH `repo` AND `workflow` scopes
- **Workaround:** Upload workflow file via GitHub API (`PUT /repos/{owner}/{repo}/contents/.github/workflows/build.yml`) with a token that HAS workflow scope
- **Verify scopes:** `curl -I -H "Authorization: token $TOKEN" https://api.github.com/user | grep x-oauth-scopes`
- **Different accounts:** Each token only works with repos under that account. Check: `curl -H "Authorization: token $TOKEN" https://api.github.com/user`

## Git Init Branch Name
`git init` defaults to `master`. GitHub expects `main`. Always run:
```bash
git init
git branch -m master main
# ... add, commit ...
git push -u origin main --force
```

## VLESS Link → Full Xray JSON Conversion
Convert a VLESS share link to the full Xray config JSON (as used by NapsterNetV):
```python
import json, urllib.parse

def vless_to_xray(url, remarks="VPN"):
    parsed = urllib.parse.urlparse(url)
    params = urllib.parse.parse_qs(parsed.query)
    
    config = {
        "remarks": remarks,
        "log": {"loglevel": "warning"},
        "inbounds": [{
            "tag": "socks", "port": 10808, "protocol": "socks",
            "settings": {"auth": "noauth", "udp": True, "userLevel": 8},
            "sniffing": {"enabled": True, "destOverride": ["http", "tls"]}
        }],
        "outbounds": [{
            "tag": "proxy", "protocol": "vless",
            "settings": {"vnext": [{
                "address": parsed.hostname,
                "port": parsed.port,
                "users": [{"id": parsed.username, "level": 8, "encryption": "none"}]
            }]},
            "streamSettings": {
                "network": params.get('type', ['tcp'])[0],
                "security": params.get('security', ['tls'])[0],
                "xhttpSettings": {
                    "path": urllib.parse.unquote(params.get('path', ['/'])[0]),
                    "host": params.get('host', [''])[0],
                    "mode": params.get('mode', ['auto'])[0],
                    "extra": json.loads(urllib.parse.unquote(params.get('extra', ['{}'])[0]))
                },
                "realitySettings": {
                    "allowInsecure": True,
                    "serverName": params.get('sni', [''])[0],
                    "fingerprint": params.get('fp', ['chrome'])[0],
                    "show": False,
                    "publicKey": params.get('pbk', [''])[0],
                    "shortId": params.get('sid', [''])[0],
                    "spiderX": urllib.parse.unquote(params.get('spx', ['/'])[0])
                }
            }
        }]
    }
    return json.dumps(config, indent=2, ensure_ascii=False)
```

## Padding Note
Default: `xPaddingBytes: "0-0"` (user chose for speed). Configurable in XrayConfigGenerator.
