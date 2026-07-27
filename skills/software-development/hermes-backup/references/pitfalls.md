# Hermes Backup Pitfalls

## Git Clone Issues

### Clone hanging on credential prompts
```bash
# BAD: hangs waiting for input
git clone https://ghp_TOKEN@github.com/owner/repo.git

# GOOD: non-interactive
GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://ghp_TOKEN@github.com/owner/repo.git
```

### Branch name mismatch
```bash
# Try main first, fallback to master
git push origin main 2>&1 || git push origin master 2>&1
```

## Security

### state.db contains tokens
- API keys
- Session tokens
- OAuth credentials
- **NEVER backup this file**

### auth.json contains credentials
- GitHub tokens
- API keys
- **NEVER backup this file**

## Performance

### Large repos
- Use `--depth 1` for initial clone
- Full git history not needed for backups
- Backup script only commits changed files

### Network timeouts
- Increase timeout for git operations
- Use HTTPS (port 443) not SSH (port 22)
- Port 22 often blocked in cloud environments