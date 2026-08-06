#!/bin/bash
set -euo pipefail

BACKUP_DIR="/data/hermes-backup"
HERMES_DIR="${HERMES_HOME:-$HOME/.hermes}"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
COMMIT_MSG="Backup: $TIMESTAMP"

# Create structure
mkdir -p "$BACKUP_DIR"/{memories,sessions,skills,config,cron}

# Copy files (with error handling)
[ -d "$HERMES_DIR/memories" ] && cp -r "$HERMES_DIR/memories/"* "$BACKUP_DIR/memories/" 2>/dev/null || true
[ -f "$HERMES_DIR/sessions/sessions.json" ] && cp "$HERMES_DIR/sessions/sessions.json" "$BACKUP_DIR/sessions/"
[ -f "$HERMES_DIR/config.yaml" ] && cp "$HERMES_DIR/config.yaml" "$BACKUP_DIR/config/"
[ -f "$HERMES_DIR/SOUL.md" ] && cp "$HERMES_DIR/SOUL.md" "$BACKUP_DIR/config/"
[ -d "$HERMES_DIR/skills" ] && cp -r "$HERMES_DIR/skills/"* "$BACKUP_DIR/skills/" 2>/dev/null || true
[ -d "$HERMES_DIR/cron" ] && cp -r "$HERMES_DIR/cron/"* "$BACKUP_DIR/cron/" 2>/dev/null || true

# Git commit & push
cd "$BACKUP_DIR"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
  git push origin main 2>&1 || git push origin master 2>&1
  echo "[OK] Pushed: $COMMIT_MSG"
else
  echo "[--] No changes"
fi
