# Migration Guide: API Key to OAuth 2.0

## Overview

This guide helps you migrate from API key authentication to the more secure OAuth 2.0 authentication for the Claude-Gemini Bridge.

## Why Migrate to OAuth?

### Security Benefits
- **No exposed credentials**: OAuth tokens are temporary and revocable
- **Encrypted storage**: Tokens stored with AES-256-CBC encryption
- **Fine-grained permissions**: Control exactly what the application can access
- **Automatic rotation**: Tokens refresh automatically before expiration

### Operational Benefits
- **Easier credential management**: No need to rotate API keys manually
- **Better audit trail**: OAuth provides detailed access logs
- **User-specific access**: Each user gets their own tokens
- **Simplified revocation**: Revoke access without changing code

## Pre-Migration Checklist

Before starting migration:

- [ ] Backup current configuration
- [ ] Note current API key location
- [ ] Verify Gemini CLI is installed (v1.0.0+)
- [ ] Have Google account credentials ready
- [ ] Schedule 15 minutes for migration
- [ ] Inform team members of the change

## Migration Steps

### Step 1: Backup Current Configuration

```bash
# Backup existing configuration
cp ~/.claude-gemini-bridge/config.json ~/.claude-gemini-bridge/config.json.backup
cp ~/.claude/settings.json ~/.claude/settings.json.backup

# Export current API key (for rollback if needed)
echo $GEMINI_API_KEY > ~/.claude-gemini-bridge/api_key.backup

# Create full backup archive
tar -czf claude-gemini-backup-$(date +%Y%m%d).tar.gz \
  ~/.claude-gemini-bridge/ \
  ~/.claude/settings.json
```

### Step 2: Run Migration Wizard

The interactive setup wizard handles the migration automatically:

```bash
# Run the setup wizard
./setup/interactive-setup.sh

# When prompted:
# 1. Select "OAuth 2.0 (Recommended)"
# 2. Choose "Gemini CLI (Easiest)"
# 3. Follow authentication prompts
```

The wizard will:
- Detect existing API key configuration
- Preserve your current settings
- Set up OAuth authentication
- Migrate hooks and preferences
- Test the new configuration

### Step 3: Authenticate with OAuth

#### Option A: Using Gemini CLI (Recommended)

```bash
# Authenticate via Gemini CLI
gemini auth login

# Browser will open for Google authentication
# Grant permissions when prompted

# Verify authentication
gemini auth print-access-token
```

#### Option B: Custom OAuth Application

```bash
# Set OAuth credentials
export OAUTH_CLIENT_ID="your-client-id"
export OAUTH_CLIENT_SECRET="your-client-secret"

# Run OAuth flow
./hooks/lib/oauth-handler.sh authenticate
```

### Step 4: Verify Migration

```bash
# Test OAuth configuration
./test/test-oauth.sh

# Expected output:
# ✅ OAuth authentication successful
# ✅ Token validation passed
# ✅ API connection verified
# ✅ Encryption working

# Test with Claude Code
claude "test gemini integration"
```

### Step 5: Clean Up API Keys

Once OAuth is working:

```bash
# Remove API key from environment
unset GEMINI_API_KEY

# Remove from shell configuration
# Edit ~/.bashrc, ~/.zshrc, or ~/.bash_profile
# Remove or comment out:
# export GEMINI_API_KEY="..."

# Clear API key from configuration
jq 'del(.api_key)' ~/.claude-gemini-bridge/config.json > /tmp/config.json
mv /tmp/config.json ~/.claude-gemini-bridge/config.json

# Secure permissions on OAuth tokens
chmod 600 ~/.claude-gemini-bridge/tokens/*
```

## Configuration Comparison

### Before Migration (API Key)

```json
{
  "auth_type": "api_key",
  "api_key": "AIzaSy...",
  "provider": "gemini-api"
}
```

### After Migration (OAuth)

```json
{
  "auth_type": "oauth",
  "provider": "gemini",
  "oauth": {
    "client_id": "...",
    "token_endpoint": "https://oauth2.googleapis.com/token",
    "scope": "https://www.googleapis.com/auth/generative-language.retriever"
  },
  "encryption": {
    "enabled": true,
    "algorithm": "aes-256-cbc"
  }
}
```

## Rollback Procedure

If you need to rollback to API key authentication:

### Quick Rollback

```bash
# Restore backup configuration
cp ~/.claude-gemini-bridge/config.json.backup ~/.claude-gemini-bridge/config.json
cp ~/.claude/settings.json.backup ~/.claude/settings.json

# Restore API key
export GEMINI_API_KEY=$(cat ~/.claude-gemini-bridge/api_key.backup)

# Restart Claude Code
```

### Manual Rollback

```bash
# Edit configuration
vi ~/.claude-gemini-bridge/config.json

# Change to:
{
  "auth_type": "api_key",
  "api_key": "your-api-key",
  "provider": "gemini-api"
}

# Set environment variable
export GEMINI_API_KEY="your-api-key"
```

## Troubleshooting Migration Issues

### Issue: "API key still being used"

**Symptoms**: OAuth configured but API key still in use

**Solution**:
```bash
# Check environment variable
echo $GEMINI_API_KEY

# If set, unset it
unset GEMINI_API_KEY

# Check configuration priority
cat ~/.claude-gemini-bridge/config.json | jq '.auth_type'
# Should show "oauth", not "api_key"
```

### Issue: "Token not found after migration"

**Symptoms**: OAuth configured but no tokens present

**Solution**:
```bash
# Re-authenticate
gemini auth login

# Or manually trigger OAuth flow
./hooks/lib/oauth-handler.sh authenticate

# Verify tokens exist
ls -la ~/.claude-gemini-bridge/tokens/
```

### Issue: "Permission denied accessing tokens"

**Symptoms**: Cannot read token files

**Solution**:
```bash
# Fix permissions
chmod 600 ~/.claude-gemini-bridge/tokens/*
chmod 700 ~/.claude-gemini-bridge/tokens/

# Verify ownership
chown -R $USER:$USER ~/.claude-gemini-bridge/
```

### Issue: "Both API key and OAuth configured"

**Symptoms**: Conflicting authentication methods

**Solution**:
```bash
# Clear API key configuration
jq 'del(.api_key) | .auth_type = "oauth"' \
  ~/.claude-gemini-bridge/config.json > /tmp/config.json
mv /tmp/config.json ~/.claude-gemini-bridge/config.json

# Unset environment variable
unset GEMINI_API_KEY
```

## Team Migration

For team environments:

### 1. Prepare Team

```markdown
# Send to team:
Subject: Migrating to OAuth Authentication

We're upgrading from API keys to OAuth for better security.

Actions required:
1. Pull latest changes
2. Run: ./setup/interactive-setup.sh
3. Choose OAuth authentication
4. Complete Google authentication
5. Test with: ./test/test-oauth.sh

Timeline: Complete by [DATE]
Support: [Contact/Channel]
```

### 2. Central Configuration

Create shared OAuth application:

```bash
# Admin creates OAuth app in Google Cloud Console
# Share these (securely):
OAUTH_CLIENT_ID="shared-client-id"
OAUTH_CLIENT_SECRET="shared-client-secret"

# Each team member authenticates individually
```

### 3. Gradual Rollout

```bash
# Phase 1: OAuth available but API keys still work
# config.json supports both methods

# Phase 2: OAuth preferred, API keys deprecated
# Warning messages for API key usage

# Phase 3: OAuth only
# API key support removed
```

## Post-Migration Checklist

After successful migration:

- [ ] OAuth tokens working correctly
- [ ] API key removed from environment
- [ ] Backup created and stored safely
- [ ] Team members notified
- [ ] Documentation updated
- [ ] CI/CD pipelines updated
- [ ] Monitoring adjusted for OAuth

## Best Practices After Migration

### 1. Regular Token Rotation

```bash
# Monthly token refresh
0 0 1 * * /path/to/hooks/lib/oauth-handler.sh refresh
```

### 2. Monitor Token Usage

```bash
# Check token access patterns
grep "oauth_token_used" logs/debug/*.log | tail -20
```

### 3. Secure Token Storage

```bash
# Verify encryption
./test/test-oauth.sh --encryption

# Check file permissions
ls -la ~/.claude-gemini-bridge/tokens/
```

### 4. Document OAuth Setup

```bash
# Generate OAuth configuration report
./hooks/lib/oauth-handler.sh status > oauth-config.txt

# Share with team (without secrets)
grep -v "secret\|token" oauth-config.txt
```

## Frequently Asked Questions

### Q: Can I use both API key and OAuth simultaneously?

A: No, the bridge uses one authentication method at a time. OAuth takes precedence if both are configured.

### Q: What happens to my API key after migration?

A: The API key remains valid but unused. You should revoke it in Google Cloud Console for security.

### Q: How often do OAuth tokens refresh?

A: Access tokens typically last 1 hour and refresh automatically. Refresh tokens last longer but vary by provider.

### Q: Can I migrate back to API keys later?

A: Yes, use the rollback procedure. However, OAuth is recommended for better security.

### Q: Will migration affect my Claude Code workflows?

A: No, the integration remains transparent. Claude Code won't notice the authentication change.

### Q: Do I need to migrate immediately?

A: API key support continues to work, but OAuth is strongly recommended for production use.

## Support

For migration assistance:

1. Run diagnostic: `./test/diagnose-migration.sh`
2. Check [OAuth Setup Guide](OAUTH_SETUP_GUIDE.md)
3. Review [Troubleshooting Guide](TROUBLESHOOTING.md)
4. Enable debug mode: `export OAUTH_DEBUG=true`
5. Contact support with migration logs

Remember: Keep backups until you're confident the migration is successful!