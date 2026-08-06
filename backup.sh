#!/bin/bash
set -euo pipefail

BACKUP_DIR="/data/hermes-backup"
HERMES_DIR="/data/.hermes"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
COMMIT_MSG="Backup: $TIMESTAMP"

# Create backup structure
mkdir -p "$BACKUP_DIR/memories"
mkdir -p "$BACKUP_DIR/sessions"
mkdir -p "$BACKUP_DIR/skills"
mkdir -p "$BACKUP_DIR/config"
# NOTE: state.db is intentionally excluded - it contains sensitive tokens

# --- 1. Memories (most critical - user's persistent knowledge) ---
if [ -d "$HERMES_DIR/memories" ] && [ "$(ls -A $HERMES_DIR/memories 2>/dev/null)" ]; then
    cp -r "$HERMES_DIR/memories/"* "$BACKUP_DIR/memories/" 2>/dev/null || true
    echo "[OK] Memories backed up"
else
    echo "[--] No memory files yet"
fi

# --- 2. Sessions database ---
if [ -f "$HERMES_DIR/sessions/sessions.json" ]; then
    cp "$HERMES_DIR/sessions/sessions.json" "$BACKUP_DIR/sessions/"
    echo "[OK] Sessions backed up"
fi
# NOTE: state.db excluded - contains sensitive tokens

# --- 3. Config & SOUL ---
if [ -f "$HERMES_DIR/config.yaml" ]; then
    cp "$HERMES_DIR/config.yaml" "$BACKUP_DIR/config/"
    echo "[OK] Config backed up"
fi
if [ -f "$HERMES_DIR/SOUL.md" ]; then
    cp "$HERMES_DIR/SOUL.md" "$BACKUP_DIR/config/"
    echo "[OK] SOUL.md backed up"
fi

# --- 4. Skills (custom skills the user has created/modified) ---
# Only back up user-created skills, not system ones
if [ -d "$HERMES_DIR/skills" ]; then
    cp -r "$HERMES_DIR/skills/"* "$BACKUP_DIR/skills/" 2>/dev/null || true
    echo "[OK] Skills backed up"
fi

# --- 5. Cron jobs config ---
if [ -d "$HERMES_DIR/cron" ]; then
    mkdir -p "$BACKUP_DIR/cron"
    cp -r "$HERMES_DIR/cron/"* "$BACKUP_DIR/cron/" 2>/dev/null || true
    echo "[OK] Cron config backed up"
fi


# --- Auto-redact sensitive tokens before committing ---
echo "[..] Redacting sensitive tokens from backed-up files..."
# Find and redact tokens in all backed-up text files
find "$BACKUP_DIR/memories" "$BACKUP_DIR/skills" "$BACKUP_DIR/config" "$BACKUP_DIR/cron" \
    -type f \( -name "*.md" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.txt" \) \
    -exec sed -i \
        -e 's/vcp_[A-Za-z0-9]\{20,\}/[REDACTED_VERCEL_TOKEN]/g' \
        -e 's/ghp_[A-Za-z0-9]\{30,\}/[REDACTED_GH_TOKEN]/g' \
        -e 's/ghp_[A-Za-z0-9]\{2\}\.[A-Za-z0-9]\{3,\}/[REDACTED_GH_TOKEN]/g' \
        -e 's/[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}/[REDACTED_UUID]/g' \
        {} +
echo "[OK] Tokens redacted"

# --- Git commit & push ---
cd "$BACKUP_DIR"
git add -A
if git diff --cached --quiet; then
    echo "[--] No changes to commit"
else
    git commit -m "$COMMIT_MSG"
    git push origin main 2>&1 || git push origin master 2>&1
    echo "[OK] Pushed to GitHub: $COMMIT_MSG"
fi

echo ""
echo "=== Backup completed at $TIMESTAMP ==="
