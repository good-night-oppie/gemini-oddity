# Security Best Practices for Claude-Gemini Bridge

## Overview

This document outlines security best practices for deploying and maintaining the Claude-Gemini Bridge with OAuth 2.0 authentication. Following these guidelines helps protect sensitive data, prevent unauthorized access, and maintain system integrity.

## Table of Contents

- [Authentication Security](#authentication-security)
- [Token Management](#token-management)
- [Encryption Standards](#encryption-standards)
- [File Permissions](#file-permissions)
- [Network Security](#network-security)
- [Logging and Monitoring](#logging-and-monitoring)
- [Development Practices](#development-practices)
- [Incident Response](#incident-response)
- [Security Checklist](#security-checklist)

## Authentication Security

### OAuth 2.0 Configuration

#### Use OAuth Over API Keys

```bash
# Always prefer OAuth
{
  "auth_type": "oauth",  # Not "api_key"
  "provider": "gemini"
}
```

**Benefits:**
- Temporary, revocable tokens
- No permanent credentials in files
- Automatic expiration
- Granular permission control

#### Secure OAuth Credentials

```bash
# Store OAuth credentials securely
# Never in code:
# ❌ client_secret = "abc123"  # NEVER DO THIS

# Use environment variables:
# ✅ 
export OAUTH_CLIENT_SECRET="${SECRET_FROM_SECURE_STORE}"

# Or encrypted configuration:
# ✅
./hooks/lib/encryption-core.sh encrypt_file config.json
```

#### Validate OAuth Providers

```bash
# Whitelist trusted OAuth endpoints
TRUSTED_AUTH_ENDPOINTS=(
  "https://accounts.google.com/o/oauth2/v2/auth"
  "https://oauth2.googleapis.com/token"
)

# Validate before use
validate_oauth_endpoint() {
  local endpoint="$1"
  for trusted in "${TRUSTED_AUTH_ENDPOINTS[@]}"; do
    [[ "$endpoint" == "$trusted" ]] && return 0
  done
  return 1
}
```

### Authentication Flow Security

#### Secure Redirect URIs

```bash
# Use localhost for development only
OAUTH_REDIRECT_URI="http://localhost:8080/callback"  # Dev only

# Production should use HTTPS
OAUTH_REDIRECT_URI="https://your-domain.com/oauth/callback"  # Production

# Validate redirect URI
[[ "$OAUTH_REDIRECT_URI" =~ ^https:// ]] || echo "WARNING: Insecure redirect URI"
```

#### PKCE Implementation

For public clients, implement PKCE (Proof Key for Code Exchange):

```bash
# Generate code verifier and challenge
generate_pkce() {
  local verifier=$(openssl rand -base64 32 | tr -d '=' | tr '+/' '-_')
  local challenge=$(echo -n "$verifier" | sha256sum | xxd -r -p | base64 | tr -d '=' | tr '+/' '-_')
  echo "verifier=$verifier"
  echo "challenge=$challenge"
}
```

## Token Management

### Token Storage Security

#### Encrypted Storage

```bash
# Always encrypt tokens at rest
encrypt_token() {
  local token="$1"
  local encrypted=$(echo "$token" | openssl enc -aes-256-cbc -salt -base64 -pass pass:"$ENCRYPTION_KEY")
  echo "$encrypted" > ~/.claude-gemini-bridge/tokens/access_token.enc
  chmod 600 ~/.claude-gemini-bridge/tokens/access_token.enc
}

# Decrypt only when needed
decrypt_token() {
  openssl enc -aes-256-cbc -d -salt -base64 -pass pass:"$ENCRYPTION_KEY" \
    -in ~/.claude-gemini-bridge/tokens/access_token.enc
}
```

#### Memory Protection

```bash
# Clear sensitive variables after use
oauth_authenticate() {
  local token="$(get_token)"
  
  # Use token
  api_call "$token"
  
  # Clear from memory
  unset token
  token=""
}

# Disable command history for sensitive operations
set +o history
export OAUTH_CLIENT_SECRET="sensitive"
set -o history
```

### Token Lifecycle

#### Automatic Rotation

```bash
# Implement token rotation
rotate_tokens() {
  # Check token age
  local token_age=$(get_token_age)
  local max_age=$((30 * 24 * 3600))  # 30 days
  
  if (( token_age > max_age )); then
    revoke_token
    authenticate_oauth
  fi
}

# Schedule rotation
crontab -e
# 0 0 * * 0 /path/to/rotate_tokens.sh
```

#### Secure Token Refresh

```bash
# Validate refresh token before use
refresh_access_token() {
  local refresh_token=$(decrypt_token "refresh")
  
  # Validate token format
  if ! validate_token_format "$refresh_token"; then
    log_security_event "Invalid refresh token format"
    return 1
  fi
  
  # Refresh with rate limiting
  if check_rate_limit "token_refresh"; then
    new_token=$(call_refresh_endpoint "$refresh_token")
    encrypt_token "$new_token"
  fi
}
```

## Encryption Standards

### AES-256-CBC Implementation

```bash
# Encryption configuration
ENCRYPTION_ALGORITHM="aes-256-cbc"
ENCRYPTION_KEY_LENGTH=32
SALT_LENGTH=16

# Generate strong encryption key
generate_encryption_key() {
  openssl rand -base64 32
}

# Encrypt sensitive data
encrypt_data() {
  local data="$1"
  local password="$2"
  
  # Generate salt
  local salt=$(openssl rand -hex 16)
  
  # Derive key using PBKDF2
  local key=$(openssl enc -aes-256-cbc -salt -pass pass:"$password$salt" -P -md sha256 | grep key | cut -d'=' -f2)
  
  # Encrypt with IV
  echo "$data" | openssl enc -aes-256-cbc -salt -iv "$salt" -K "$key" -base64
}
```

### Key Management

```bash
# Key storage best practices
store_encryption_key() {
  local key="$1"
  
  # Use system keyring when available
  if command -v secret-tool &>/dev/null; then
    echo "$key" | secret-tool store --label="Claude-Gemini Bridge" service oauth-encryption
  else
    # Fall back to file with strict permissions
    echo "$key" > ~/.claude-gemini-bridge/.encryption_key
    chmod 400 ~/.claude-gemini-bridge/.encryption_key
  fi
}

# Key rotation schedule
rotate_encryption_keys() {
  # Generate new key
  local new_key=$(generate_encryption_key)
  
  # Re-encrypt all tokens with new key
  reencrypt_all_tokens "$new_key"
  
  # Update key storage
  store_encryption_key "$new_key"
  
  # Log rotation
  log_security_event "Encryption key rotated"
}
```

## File Permissions

### Directory Structure Security

```bash
# Set secure permissions on installation
secure_installation() {
  # Configuration directory
  chmod 700 ~/.claude-gemini-bridge
  
  # Token storage
  chmod 700 ~/.claude-gemini-bridge/tokens
  find ~/.claude-gemini-bridge/tokens -type f -exec chmod 600 {} \;
  
  # Configuration files
  chmod 600 ~/.claude-gemini-bridge/config.json
  chmod 600 ~/.claude-gemini-bridge/.encryption_key
  
  # Log directory
  chmod 755 ~/.claude-gemini-bridge/logs
  find ~/.claude-gemini-bridge/logs -type f -exec chmod 644 {} \;
}

# Verify permissions regularly
verify_permissions() {
  local issues=0
  
  # Check token directory
  if [[ $(stat -c %a ~/.claude-gemini-bridge/tokens 2>/dev/null) != "700" ]]; then
    echo "WARNING: Insecure token directory permissions"
    ((issues++))
  fi
  
  # Check token files
  while IFS= read -r token_file; do
    if [[ $(stat -c %a "$token_file") != "600" ]]; then
      echo "WARNING: Insecure token file: $token_file"
      ((issues++))
    fi
  done < <(find ~/.claude-gemini-bridge/tokens -type f)
  
  return $issues
}
```

### Ownership Verification

```bash
# Ensure correct ownership
verify_ownership() {
  local current_user=$(id -u)
  local current_group=$(id -g)
  
  find ~/.claude-gemini-bridge -type f -o -type d | while read -r path; do
    local owner=$(stat -c %u "$path")
    if [[ "$owner" != "$current_user" ]]; then
      echo "ERROR: Incorrect ownership on $path"
      chown "$current_user:$current_group" "$path"
    fi
  done
}
```

## Network Security

### HTTPS Enforcement

```bash
# Force HTTPS for API calls
enforce_https() {
  local url="$1"
  
  # Reject non-HTTPS URLs
  if [[ ! "$url" =~ ^https:// ]]; then
    log_security_event "Blocked non-HTTPS request: $url"
    return 1
  fi
  
  # Verify certificate
  curl --fail --silent --show-error \
    --cacert /etc/ssl/certs/ca-certificates.crt \
    "$url"
}
```

### Proxy Configuration

```bash
# Secure proxy settings
configure_proxy() {
  # Use HTTPS proxy
  export HTTPS_PROXY="https://proxy.company.com:8080"
  
  # Exclude local addresses
  export NO_PROXY="localhost,127.0.0.1,*.local"
  
  # Authenticate proxy
  export HTTPS_PROXY="https://user:pass@proxy.company.com:8080"
}
```

### Rate Limiting

```bash
# Implement rate limiting
RATE_LIMIT_WINDOW=60  # seconds
RATE_LIMIT_MAX_REQUESTS=10

check_rate_limit() {
  local operation="$1"
  local count=$(redis-cli GET "rate_limit:$operation" 2>/dev/null || echo 0)
  
  if (( count >= RATE_LIMIT_MAX_REQUESTS )); then
    log_security_event "Rate limit exceeded for $operation"
    return 1
  fi
  
  redis-cli INCR "rate_limit:$operation" &>/dev/null
  redis-cli EXPIRE "rate_limit:$operation" $RATE_LIMIT_WINDOW &>/dev/null
  return 0
}
```

## Logging and Monitoring

### Security Event Logging

```bash
# Log security events
log_security_event() {
  local event="$1"
  local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
  local caller="${BASH_SOURCE[1]}:${BASH_LINENO[0]}"
  
  # Log format: timestamp | severity | event | caller | details
  echo "$timestamp | SECURITY | $event | $caller" >> ~/.claude-gemini-bridge/logs/security.log
  
  # Alert on critical events
  if [[ "$event" =~ (breach|unauthorized|injection) ]]; then
    send_security_alert "$event"
  fi
}

# Monitor for suspicious activity
monitor_security_logs() {
  # Check for repeated failures
  local auth_failures=$(grep -c "auth_failed" ~/.claude-gemini-bridge/logs/security.log)
  if (( auth_failures > 5 )); then
    log_security_event "Multiple authentication failures detected"
  fi
  
  # Check for unusual patterns
  local unusual_hours=$(grep -E "0[0-5]:[0-9]{2}:[0-9]{2}" ~/.claude-gemini-bridge/logs/security.log | wc -l)
  if (( unusual_hours > 0 )); then
    log_security_event "Activity detected during unusual hours"
  fi
}
```

### Audit Trail

```bash
# Maintain audit trail
audit_log() {
  local action="$1"
  local details="$2"
  local user=$(whoami)
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  cat >> ~/.claude-gemini-bridge/logs/audit.log <<EOF
{
  "timestamp": "$timestamp",
  "user": "$user",
  "action": "$action",
  "details": "$details",
  "pid": $$,
  "session": "$CLAUDE_SESSION_ID"
}
EOF
}

# Audit critical operations
audit_oauth_operation() {
  audit_log "oauth_$1" "$2"
}

audit_token_operation() {
  audit_log "token_$1" "$2"
}
```

### Log Rotation and Retention

```bash
# Rotate logs securely
rotate_logs() {
  local log_dir=~/.claude-gemini-bridge/logs
  local retention_days=90
  
  # Compress old logs
  find "$log_dir" -name "*.log" -mtime +7 -exec gzip {} \;
  
  # Delete old compressed logs
  find "$log_dir" -name "*.log.gz" -mtime +$retention_days -delete
  
  # Ensure permissions on new logs
  find "$log_dir" -name "*.log" -exec chmod 644 {} \;
}
```

## Development Practices

### Secure Coding Guidelines

```bash
# Input validation
validate_input() {
  local input="$1"
  local pattern="$2"
  
  # Sanitize input
  input=$(echo "$input" | tr -d '\n\r' | sed 's/[;&|`]//g')
  
  # Validate against pattern
  if [[ ! "$input" =~ $pattern ]]; then
    log_security_event "Invalid input rejected: $input"
    return 1
  fi
  
  echo "$input"
}

# Command injection prevention
safe_execute() {
  local command="$1"
  shift
  
  # Use array for arguments (prevents injection)
  local args=("$@")
  
  # Execute with validation
  if validate_command "$command"; then
    "$command" "${args[@]}"
  fi
}
```

### Dependency Management

```bash
# Check for vulnerable dependencies
check_vulnerabilities() {
  # Check npm packages
  if [[ -f package.json ]]; then
    npm audit
  fi
  
  # Check shell scripts
  shellcheck hooks/**/*.sh
  
  # Check for known vulnerable patterns
  grep -r "eval\|exec\|\$(\|system(" hooks/
}
```

### Secret Scanning

```bash
# Pre-commit hook for secret detection
detect_secrets() {
  local files="$@"
  
  # Patterns for common secrets
  local patterns=(
    "api[_-]?key.*=.*['\"][^'\"]{20,}['\"]"
    "secret.*=.*['\"][^'\"]{20,}['\"]"
    "password.*=.*['\"][^'\"]{8,}['\"]"
    "token.*=.*['\"][^'\"]{20,}['\"]"
    "AIza[0-9A-Za-z_-]{35}"  # Google API key
  )
  
  for pattern in "${patterns[@]}"; do
    if grep -E "$pattern" $files; then
      echo "ERROR: Potential secret detected"
      return 1
    fi
  done
}
```

## Incident Response

### Security Incident Procedure

```bash
# Incident response script
respond_to_incident() {
  local incident_type="$1"
  
  case "$incident_type" in
    "token_leak")
      # Immediately revoke all tokens
      ./hooks/lib/oauth-handler.sh revoke --all
      # Generate new tokens
      ./hooks/lib/oauth-handler.sh authenticate
      # Audit access logs
      audit_recent_access
      ;;
      
    "unauthorized_access")
      # Lock down system
      chmod 000 ~/.claude-gemini-bridge/tokens
      # Alert administrator
      send_security_alert "Unauthorized access detected"
      # Review audit logs
      analyze_audit_logs
      ;;
      
    "credential_compromise")
      # Rotate all credentials
      rotate_all_credentials
      # Force re-authentication
      force_reauthentication
      # Update security policies
      update_security_policies
      ;;
  esac
  
  # Log incident
  log_security_incident "$incident_type"
}
```

### Recovery Procedures

```bash
# Backup recovery
restore_secure_backup() {
  local backup_file="$1"
  
  # Verify backup integrity
  if ! verify_backup_integrity "$backup_file"; then
    echo "ERROR: Backup integrity check failed"
    return 1
  fi
  
  # Restore with secure permissions
  tar -xzf "$backup_file" -C ~/
  secure_installation
  
  # Force credential rotation
  rotate_all_credentials
}

# System recovery
recover_from_breach() {
  # Revoke all access
  revoke_all_access
  
  # Clean potentially compromised files
  clean_compromised_files
  
  # Reinstall with fresh credentials
  ./install.sh --clean --secure
  
  # Audit all recent activity
  comprehensive_audit
}
```

## Security Checklist

### Daily Checks
- [ ] Verify token expiration status
- [ ] Check authentication logs for failures
- [ ] Review rate limiting counters
- [ ] Monitor disk space for logs

### Weekly Checks
- [ ] Rotate access tokens
- [ ] Review security event logs
- [ ] Check file permissions
- [ ] Update dependencies

### Monthly Checks
- [ ] Rotate encryption keys
- [ ] Full security audit
- [ ] Review and update OAuth scopes
- [ ] Test incident response procedures

### Deployment Checklist
- [ ] Remove all debugging code
- [ ] Disable verbose logging
- [ ] Verify HTTPS enforcement
- [ ] Set production permissions
- [ ] Enable rate limiting
- [ ] Configure log rotation
- [ ] Test token refresh flow
- [ ] Verify encryption working
- [ ] Document security contacts

## Security Contacts

```bash
# Security configuration
SECURITY_CONTACT="security@your-domain.com"
SECURITY_WEBHOOK="https://your-domain.com/security-alerts"

# Alert function
send_security_alert() {
  local message="$1"
  local priority="${2:-HIGH}"
  
  # Send email alert
  echo "$message" | mail -s "Security Alert: $priority" "$SECURITY_CONTACT"
  
  # Send webhook alert
  curl -X POST "$SECURITY_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{\"priority\":\"$priority\",\"message\":\"$message\"}"
}
```

## Additional Resources

- [OWASP Security Guidelines](https://owasp.org)
- [Google OAuth 2.0 Security Best Practices](https://developers.google.com/identity/protocols/oauth2/best-practices)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Security Benchmarks](https://www.cisecurity.org/benchmarks)

Remember: Security is not a one-time setup but an ongoing process. Regular reviews, updates, and vigilance are essential for maintaining a secure system.