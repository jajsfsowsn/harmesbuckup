---
name: hermes-backup
description: "Backup Hermes memory/config to GitHub with cron."
---

# Hermes Backup to GitHub

Automated backup of Hermes critical files to GitHub with cron scheduling.

## What to Backup

- memories/ (CRITICAL)
- sessions/sessions.json
- config.yaml, SOUL.md
- skills/
- cron/

## What to EXCLUDE

- state.db (contains tokens)
- *.db-wal, *.db-shm
- auth.json

## Setup

```bash
GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://ghp_TOKEN@github.com/owner/repo.git /data/hermes-backup
```

Schedule with: `cronjob create schedule="0 */12 * * *"`

## Script

See `scripts/backup.sh` for the full backup script template.

## Pitfalls

See `references/pitfalls.md` for common issues and solutions.