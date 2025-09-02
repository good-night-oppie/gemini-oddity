# Troubleshooting Guide for Gemini Oddity

## 🔧 Common Problems and Solutions

### Installation & Setup

#### Hook not executing
**Symptom:** Claude behaves normally, but Gemini is never called

**Solution steps:**
1. Check Claude Settings:
   ```bash
   cat ~/.claude/settings.json
   ```
   
2. Test hook manually:
   ```bash
   echo '{"tool_name":"Read","tool_input":{"file_path":"test.txt"},"session_id":"test"}' | ./hooks/gemini-bridge.sh
   ```

3. Check permissions:
   ```bash
   ls -la hooks/gemini-bridge.sh
   # Should be executable (x-flag)
   ```

4. Check hook configuration:
   ```bash
   jq '.hooks' ~/.claude/settings.json
   ```

**Solution:** Run re-installation:
```bash
./install.sh
```

---

#### "command not found: jq"
**Symptom:** Error when running scripts

**Solution:**
- **macOS:** `brew install jq`
- **Linux:** `sudo apt-get install jq`
- **Alternative:** Use the installer, which checks jq dependencies

---

#### "command not found: gemini"
**Symptom:** Bridge cannot find Gemini

**Solution steps:**
1. Check Gemini installation:
   ```bash
   which gemini
   gemini --version
   ```

2. Test Gemini manually:
   ```bash
   echo "Test" | gemini -p "Say hello"
   ```

3. Check PATH:
   ```bash
   echo $PATH
   ```

**Solution:** Install Gemini CLI or add to PATH

---

### Gemini Integration

#### Gemini not responding
**Symptom:** Hook runs, but Gemini doesn't return responses

**Debug steps:**
1. Enable verbose logging:
   ```bash
   # In hooks/config/debug.conf
   DEBUG_LEVEL=3
   ```

2. Check Gemini logs:
   ```bash
   tail -f logs/debug/$(date +%Y%m%d).log | grep -i gemini
   ```

3. Test Gemini API key:
   ```bash
   gemini "test" -p "Hello"
   ```

**Common causes:**
- Missing or invalid API key
- Rate limiting reached
- Network problems
- Gemini service unavailable

---

#### "Rate limiting: sleeping Xs"
**Symptom:** Bridge waits between calls

**Explanation:** Normal! Prevents API overload.

**Adjust:**
```bash
# In debug.conf
GEMINI_RATE_LIMIT=0.5  # Reduce to 0.5 seconds
```

---

#### Cache problems
**Symptom:** Outdated responses from Gemini

**Solution:**
```bash
# Clear cache completely
rm -rf cache/gemini/*

# Or reduce cache TTL (in debug.conf)
GEMINI_CACHE_TTL=1800  # 30 minutes instead of 1 hour
```

---

### Path Conversion

#### @ paths not converted
**Symptom:** Gemini cannot find files

**Debug:**
1. Test path conversion in isolation:
   ```bash
   cd hooks/lib
   source path-converter.sh
   convert_claude_paths "@src/main.py" "/Users/tim/project"
   ```

2. Check working directory in logs:
   ```bash
   grep "Working directory" logs/debug/$(date +%Y%m%d).log
   ```

**Common causes:**
- Missing working_directory in tool call
- Relative paths without @ prefix
- Incorrect directory structures

---

### Performance & Behavior

#### Gemini called too often
**Symptom:** Every small Read command goes to Gemini

**Adjustments in debug.conf:**
```bash
MIN_FILES_FOR_GEMINI=5        # Increase minimum file count
CLAUDE_TOKEN_LIMIT=100000     # Increase token threshold
```

---

#### Gemini never called
**Symptom:** Even large analyses don't go to Gemini

**Debug:**
1. Enable DRY_RUN mode:
   ```bash
   # In debug.conf
   DRY_RUN=true
   ```

2. Check decision logic:
   ```bash
   grep "should_delegate_to_gemini" logs/debug/$(date +%Y%m%d).log
   ```

**Adjustments:**
```bash
MIN_FILES_FOR_GEMINI=1        # Reduce thresholds
CLAUDE_TOKEN_LIMIT=10000      # Lower token limit
```

---

## 🔍 Debug Workflow

### 1. Reproduce problem
```bash
# Enable input capturing
# In debug.conf: CAPTURE_INPUTS=true

# Run problematic Claude command
# Input will be automatically saved
```

### 2. Analyze logs
```bash
# Current debug logs
tail -f logs/debug/$(date +%Y%m%d).log

# Error logs
tail -f logs/debug/errors.log

# All logs of the day
less logs/debug/$(date +%Y%m%d).log
```

### 3. Test in isolation
```bash
# Interactive tests
./test/manual-test.sh

# Automated tests
./test/test-runner.sh

# Replay saved inputs
ls debug/captured/
cat debug/captured/FILENAME.json | ./hooks/gemini-bridge.sh
```

### 4. Step-by-step debugging
```bash
# Highest debug level
# In debug.conf: DEBUG_LEVEL=3

# Dry-run mode (no actual Gemini call)
# In debug.conf: DRY_RUN=true

# Test individual library functions
./hooks/lib/path-converter.sh
./hooks/lib/json-parser.sh
./hooks/lib/gemini-wrapper.sh
```

---

## ⚙️ Configuration

### Debug levels
```bash
# In hooks/config/debug.conf

DEBUG_LEVEL=0  # No debug output
DEBUG_LEVEL=1  # Basic information (default)
DEBUG_LEVEL=2  # Detailed information
DEBUG_LEVEL=3  # Complete tracing
```

### Gemini settings
```bash
GEMINI_CACHE_TTL=3600      # Cache time in seconds
GEMINI_TIMEOUT=30          # Timeout per call
GEMINI_RATE_LIMIT=1        # Seconds between calls
GEMINI_MAX_FILES=20        # Max files per call
```

### Decision criteria
```bash
MIN_FILES_FOR_GEMINI=3           # Minimum file count
CLAUDE_TOKEN_LIMIT=50000         # Token threshold (~200KB)
GEMINI_TOKEN_LIMIT=800000        # Max tokens for Gemini
MAX_TOTAL_SIZE_FOR_GEMINI=10485760  # Max total size (10MB)

# Excluded files
GEMINI_EXCLUDE_PATTERNS="*.secret|*.key|*.env|*.password"
```

---

## 🧹 Maintenance

### Clear cache
```bash
# Manually
rm -rf cache/gemini/*

# Automatically (via debug.conf)
AUTO_CLEANUP_CACHE=true
CACHE_MAX_AGE_HOURS=24
```

### Clear logs
```bash
# Manually
rm -rf logs/debug/*

# Automatically (via debug.conf)
AUTO_CLEANUP_LOGS=true
LOG_MAX_AGE_DAYS=7
```

### Clear captured inputs
```bash
rm -rf debug/captured/*
```

---

## 🆘 Emergency Deactivation

### Temporarily disable hook
```bash
# Backup settings
cp ~/.claude/settings.json ~/.claude/settings.json.backup

# Remove hook
jq 'del(.hooks)' ~/.claude/settings.json > /tmp/claude_settings
mv /tmp/claude_settings ~/.claude/settings.json
```

### Re-enable hook
```bash
# Restore settings
cp ~/.claude/settings.json.backup ~/.claude/settings.json

# Or reinstall
./install.sh
```

### Complete uninstallation
```bash
# Remove hook
jq 'del(.hooks)' ~/.claude/settings.json > /tmp/claude_settings
mv /tmp/claude_settings ~/.claude/settings.json

# Remove bridge
rm -rf ~/gemini-oddity
```

---

## 📞 Support & Reporting

### Collect logs for support
```bash
# Create debug package
tar -czf claude-gemini-debug-$(date +%Y%m%d).tar.gz \
  ~/.claude/settings.json \
  logs/debug/ \
  hooks/config/debug.conf
```

### Helpful information
- Claude Version: `claude --version`
- Gemini Version: `gemini --version`
- Operating System: `uname -a`
- Shell: `echo $SHELL`
- PATH: `echo $PATH`

### Common error messages
- **"Invalid JSON received"**: Input validation failed
- **"Gemini initialization failed"**: Gemini CLI not available
- **"Files too large/small"**: Thresholds not met
- **"Rate limiting"**: Normal, shows correct function
- **"Cache expired"**: Normal, cache being renewed

---

## 🔐 OAuth Authentication Issues

### OAuth Setup Problems

#### "Token expired" during operation
**Symptom:** Operations fail with token expiration error

**Solution steps:**
1. Check token status:
   ```bash
   ./hooks/lib/oauth-handler.sh status
   ```

2. Refresh token manually:
   ```bash
   ./hooks/lib/oauth-handler.sh refresh
   ```

3. If refresh fails, re-authenticate:
   ```bash
   gemini auth login
   # Or
   ./hooks/lib/oauth-handler.sh authenticate
   ```

---

#### "Invalid client" error
**Symptom:** OAuth authentication fails with client error

**Debug steps:**
1. Verify OAuth credentials:
   ```bash
   cat ~/.gemini-oddity/config.json | jq '.oauth.client_id'
   ```

2. Check Google Cloud Console:
   - Verify client ID matches
   - Check client secret is correct
   - Ensure OAuth consent screen configured

3. Re-run setup:
   ```bash
   ./setup/interactive-setup.sh --force
   ```

---

#### Browser doesn't open for OAuth
**Symptom:** No browser opens during authentication

**Solution for SSH/headless systems:**
1. Get authorization URL manually:
   ```bash
   ./hooks/lib/oauth-handler.sh get-auth-url
   ```

2. Copy URL and open in local browser

3. After authorization, copy code and set:
   ```bash
   ./hooks/lib/oauth-handler.sh set-auth-code "AUTH_CODE_HERE"
   ```

---

#### "Token decryption failed"
**Symptom:** Cannot decrypt stored OAuth tokens

**Solution steps:**
1. Check encryption key:
   ```bash
   ls -la ~/.gemini-oddity/.encryption_key
   ```

2. Clear corrupted tokens:
   ```bash
   rm -rf ~/.gemini-oddity/tokens/
   ```

3. Re-authenticate:
   ```bash
   ./setup/interactive-setup.sh
   ```

---

### OAuth Token Issues

#### Tokens not refreshing automatically
**Symptom:** Manual refresh required frequently

**Debug:**
```bash
# Check refresh token
./hooks/lib/oauth-handler.sh validate-refresh

# Check auto-refresh configuration
grep "auto_refresh" ~/.gemini-oddity/config.json

# Enable auto-refresh
jq '.oauth.auto_refresh = true' ~/.gemini-oddity/config.json > /tmp/config
mv /tmp/config ~/.gemini-oddity/config.json
```

---

#### "Insufficient scopes" error
**Symptom:** API calls fail with permission errors

**Solution:**
1. Check current scopes:
   ```bash
   ./hooks/lib/oauth-handler.sh scopes
   ```

2. Update required scopes:
   ```bash
   # Edit config.json
   vi ~/.gemini-oddity/config.json
   # Add required scope:
   # "scope": "https://www.googleapis.com/auth/generative-language.retriever"
   ```

3. Re-authenticate with new scopes:
   ```bash
   ./hooks/lib/oauth-handler.sh revoke
   ./hooks/lib/oauth-handler.sh authenticate
   ```

---

### OAuth Migration Issues

#### API key still being used after migration
**Symptom:** OAuth configured but API key in use

**Solution:**
```bash
# Check environment
echo $GEMINI_API_KEY
unset GEMINI_API_KEY

# Remove from shell config
sed -i '/GEMINI_API_KEY/d' ~/.bashrc ~/.zshrc

# Verify OAuth active
cat ~/.gemini-oddity/config.json | jq '.auth_type'
# Should show "oauth"
```

---

#### Both authentication methods configured
**Symptom:** Conflict between API key and OAuth

**Fix:**
```bash
# Clean configuration
jq 'del(.api_key) | .auth_type = "oauth"' \
  ~/.gemini-oddity/config.json > /tmp/config.json
mv /tmp/config.json ~/.gemini-oddity/config.json

# Restart Claude Code
```

---

### OAuth Security Issues

#### Tokens visible in logs
**Symptom:** Security risk from exposed tokens

**Solution:**
1. Check log files:
   ```bash
   grep -r "token\|secret" logs/
   ```

2. Clear sensitive logs:
   ```bash
   find logs/ -type f -exec sed -i 's/token=.*/token=REDACTED/g' {} \;
   ```

3. Enable log filtering:
   ```bash
   # In debug.conf
   FILTER_SENSITIVE_DATA=true
   ```

---

#### Token files have wrong permissions
**Symptom:** Security warning about file permissions

**Fix permissions:**
```bash
# Set secure permissions
chmod 700 ~/.gemini-oddity
chmod 700 ~/.gemini-oddity/tokens
chmod 600 ~/.gemini-oddity/tokens/*
chmod 600 ~/.gemini-oddity/config.json

# Verify
ls -la ~/.gemini-oddity/tokens/
```

---

## 📊 OAuth Debugging

### Enable OAuth Debug Mode

```bash
# Set debug environment
export OAUTH_DEBUG=true
export DEBUG_LEVEL=3

# Run with verbose output
./hooks/lib/oauth-handler.sh authenticate 2>&1 | tee oauth_debug.log
```

### OAuth Flow Tracing

```bash
# Trace OAuth flow
./test/trace-oauth-flow.sh

# Output shows:
# 1. Authorization URL generation
# 2. User authorization
# 3. Code exchange
# 4. Token receipt
# 5. Token encryption and storage
```

### Token Validation

```bash
# Comprehensive token check
./hooks/lib/oauth-handler.sh validate --verbose

# Checks:
# - Token exists
# - Token not expired  
# - Token decrypts properly
# - Token has required scopes
# - Refresh token valid
```

---

## 🔄 OAuth Recovery

### Complete OAuth Reset

```bash
# Full OAuth reset
./scripts/reset-oauth.sh

# Or manually:
rm -rf ~/.gemini-oddity/tokens/
rm -f ~/.gemini-oddity/.encryption_key
jq 'del(.oauth.tokens)' ~/.gemini-oddity/config.json > /tmp/config
mv /tmp/config ~/.gemini-oddity/config.json

# Re-authenticate
./setup/interactive-setup.sh
```

### Backup and Restore OAuth

```bash
# Backup OAuth configuration
tar -czf oauth-backup-$(date +%Y%m%d).tar.gz \
  ~/.gemini-oddity/config.json \
  ~/.gemini-oddity/tokens/ \
  ~/.gemini-oddity/.encryption_key

# Restore OAuth configuration
tar -xzf oauth-backup-20240101.tar.gz -C ~/
chmod 600 ~/.gemini-oddity/tokens/*
```