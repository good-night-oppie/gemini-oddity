# Gemini Oddity API Reference

## Provider System API

The Gemini Oddity uses a modular provider system for authentication and API communication. Providers implement a standard interface that allows different authentication methods and API backends.

## Provider Interface

### Required Functions

Every provider must implement these core functions:

#### `provider_init()`
Initialize the provider and verify dependencies.

**Returns:**
- `0` - Success
- `1` - Failure (missing dependencies or configuration)

**Example:**
```bash
provider_init() {
    # Check for required commands
    command -v gemini &>/dev/null || return 1
    
    # Initialize configuration
    load_config
    
    return 0
}
```

#### `provider_authenticate()`
Handle authentication flow for the provider.

**Parameters:**
- None (reads from environment and config)

**Returns:**
- `0` - Success
- `1` - Authentication failed

**Example:**
```bash
provider_authenticate() {
    case "$AUTH_TYPE" in
        oauth)
            oauth_authenticate
            ;;
        api_key)
            validate_api_key
            ;;
        *)
            return 1
            ;;
    esac
}
```

#### `provider_execute(prompt, files)`
Execute an API request with the given prompt and optional files.

**Parameters:**
- `$1` - Text prompt for the API
- `$2` - Optional: Space-separated list of file paths

**Returns:**
- API response on stdout
- Error code: `0` for success, non-zero for failure

**Example:**
```bash
provider_execute() {
    local prompt="$1"
    local files="$2"
    
    # Get authentication token
    local token=$(get_auth_token)
    
    # Make API call
    call_api "$token" "$prompt" "$files"
}
```

### Optional Functions

#### `provider_validate()`
Validate provider configuration and credentials.

**Returns:**
- `0` - Valid configuration
- `1` - Invalid or missing configuration

#### `provider_refresh_token()`
Refresh OAuth access token using refresh token.

**Returns:**
- `0` - Token refreshed successfully
- `1` - Refresh failed

#### `provider_revoke_tokens()`
Revoke all OAuth tokens and clear authentication.

**Returns:**
- `0` - Tokens revoked
- `1` - Revocation failed

## OAuth Handler API

The OAuth handler library (`hooks/lib/oauth-handler.sh`) provides these functions:

### Core Functions

#### `oauth_authenticate()`
Start OAuth authentication flow.

**Usage:**
```bash
oauth_authenticate
```

**Flow:**
1. Generate authorization URL
2. Open browser for user consent
3. Exchange authorization code for tokens
4. Encrypt and store tokens

#### `oauth_refresh_token()`
Refresh expired access token.

**Usage:**
```bash
oauth_refresh_token
```

**Returns:**
- New access token on stdout
- `0` for success, `1` for failure

#### `oauth_get_access_token()`
Retrieve current access token (refreshes if needed).

**Usage:**
```bash
token=$(oauth_get_access_token)
```

**Returns:**
- Valid access token on stdout
- Empty string if no valid token

#### `oauth_revoke_tokens()`
Revoke all tokens and clear storage.

**Usage:**
```bash
oauth_revoke_tokens
```

### Utility Functions

#### `oauth_status()`
Display current OAuth status.

**Usage:**
```bash
oauth_status
```

**Output:**
```
OAuth Status:
  Provider: gemini
  Token Status: valid
  Expires: 2024-01-01 12:00:00
  Refresh Token: present
```

#### `oauth_validate_config()`
Validate OAuth configuration.

**Usage:**
```bash
oauth_validate_config || setup_oauth
```

**Returns:**
- `0` - Valid configuration
- `1` - Missing or invalid configuration

## Encryption Core API

The encryption library (`hooks/lib/encryption-core.sh`) provides:

### Functions

#### `encrypt_data(data, password)`
Encrypt data using AES-256-CBC.

**Usage:**
```bash
encrypted=$(encrypt_data "$sensitive_data" "$password")
```

**Parameters:**
- `$1` - Data to encrypt
- `$2` - Encryption password

**Returns:**
- Base64-encoded encrypted data

#### `decrypt_data(encrypted, password)`
Decrypt AES-256-CBC encrypted data.

**Usage:**
```bash
decrypted=$(decrypt_data "$encrypted_data" "$password")
```

**Parameters:**
- `$1` - Base64-encoded encrypted data
- `$2` - Decryption password

**Returns:**
- Decrypted plaintext

#### `encrypt_file(input_file, output_file, password)`
Encrypt a file.

**Usage:**
```bash
encrypt_file "token.txt" "token.enc" "$password"
```

#### `decrypt_file(input_file, output_file, password)`
Decrypt a file.

**Usage:**
```bash
decrypt_file "token.enc" "token.txt" "$password"
```

## Configuration API

### Configuration File Format

```json
{
  "auth_type": "oauth|api_key",
  "provider": "gemini|custom",
  "api_key": "...",  // For API key auth
  "oauth": {          // For OAuth auth
    "client_id": "...",
    "client_secret": "...",
    "redirect_uri": "http://localhost:8080/callback",
    "scope": "https://www.googleapis.com/auth/generative-language.retriever",
    "token_endpoint": "https://oauth2.googleapis.com/token",
    "auth_endpoint": "https://accounts.google.com/o/oauth2/v2/auth",
    "auto_refresh": true
  },
  "encryption": {
    "enabled": true,
    "algorithm": "aes-256-cbc"
  }
}
```

### Configuration Functions

#### `load_config()`
Load configuration from JSON file.

**Usage:**
```bash
load_config
echo "Auth type: $AUTH_TYPE"
echo "Provider: $PROVIDER"
```

#### `save_config()`
Save current configuration to JSON file.

**Usage:**
```bash
AUTH_TYPE="oauth"
PROVIDER="gemini"
save_config
```

#### `get_config_value(key)`
Get specific configuration value.

**Usage:**
```bash
client_id=$(get_config_value "oauth.client_id")
```

## Environment Variables

### Required Variables

#### For OAuth Authentication
- `OAUTH_CLIENT_ID` - OAuth client ID
- `OAUTH_CLIENT_SECRET` - OAuth client secret

#### For API Key Authentication
- `GEMINI_API_KEY` - Gemini API key

### Optional Variables

#### OAuth Configuration
- `OAUTH_REDIRECT_URI` - OAuth redirect URI (default: `http://localhost:8080/callback`)
- `OAUTH_SCOPE` - OAuth scopes (default: Gemini language API scope)
- `OAUTH_AUTH_ENDPOINT` - Authorization endpoint
- `OAUTH_TOKEN_ENDPOINT` - Token endpoint
- `OAUTH_ENCRYPTION_PASSWORD` - Password for token encryption

#### Debug Configuration
- `OAUTH_DEBUG` - Enable OAuth debug output (`true`/`false`)
- `DEBUG_LEVEL` - Debug verbosity (0-3)
- `DRY_RUN` - Test mode without API calls (`true`/`false`)

## Error Codes

Standard error codes used throughout the API:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General failure |
| 2 | Authentication required |
| 3 | Token expired |
| 4 | Invalid configuration |
| 5 | Network error |
| 6 | Rate limit exceeded |
| 7 | Invalid input |
| 8 | Encryption error |
| 9 | File not found |
| 10 | Permission denied |

## Examples

### Implementing a Custom Provider

```bash
#!/bin/bash
# hooks/providers/custom-provider.sh

# Source base provider functions
source "$(dirname "$0")/../lib/base-provider.sh"

# Initialize provider
provider_init() {
    # Check dependencies
    command -v custom_cli &>/dev/null || {
        echo "Error: custom_cli not found" >&2
        return 1
    }
    
    # Load configuration
    load_config
    
    return 0
}

# Authenticate
provider_authenticate() {
    if [[ "$AUTH_TYPE" == "oauth" ]]; then
        oauth_authenticate
    else
        # Custom authentication logic
        custom_cli auth login
    fi
}

# Execute API request
provider_execute() {
    local prompt="$1"
    local files="$2"
    
    # Get token
    local token=$(oauth_get_access_token)
    
    # Make API call
    custom_cli api call \
        --token "$token" \
        --prompt "$prompt" \
        --files "$files"
}

# Export functions
export -f provider_init
export -f provider_authenticate
export -f provider_execute
```

### Using the OAuth Handler

```bash
#!/bin/bash
# Example script using OAuth

# Source OAuth handler
source ./hooks/lib/oauth-handler.sh

# Check authentication status
if ! oauth_status >/dev/null 2>&1; then
    echo "Not authenticated. Starting OAuth flow..."
    oauth_authenticate || exit 1
fi

# Get access token
token=$(oauth_get_access_token)

# Use token for API call
curl -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Hello, Gemini!"}' \
     https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent

# Refresh token if needed
if [[ $? -eq 401 ]]; then
    echo "Token expired, refreshing..."
    token=$(oauth_refresh_token)
    # Retry API call
fi
```

### Error Handling

```bash
#!/bin/bash
# Robust error handling example

handle_oauth_error() {
    local error_code=$1
    
    case $error_code in
        2)
            echo "Authentication required"
            oauth_authenticate
            ;;
        3)
            echo "Token expired, refreshing..."
            oauth_refresh_token
            ;;
        4)
            echo "Invalid configuration"
            ./setup/interactive-setup.sh
            ;;
        5)
            echo "Network error, retrying..."
            sleep 5
            return 1  # Trigger retry
            ;;
        *)
            echo "Unknown error: $error_code"
            return 1
            ;;
    esac
}

# Make API call with retry logic
retry_count=0
max_retries=3

while (( retry_count < max_retries )); do
    if provider_execute "$prompt" "$files"; then
        break
    else
        handle_oauth_error $? || {
            ((retry_count++))
            continue
        }
    fi
done
```

## Testing

### Unit Tests

Each provider should include unit tests:

```bash
#!/bin/bash
# test/test-provider.sh

test_provider_init() {
    provider_init
    assert_equal $? 0 "Provider initialization"
}

test_provider_authenticate() {
    # Mock OAuth flow
    mock_oauth_authenticate() {
        echo "mock_token"
        return 0
    }
    
    provider_authenticate
    assert_equal $? 0 "Provider authentication"
}

test_provider_execute() {
    # Mock API call
    mock_api_call() {
        echo '{"response": "test"}'
        return 0
    }
    
    response=$(provider_execute "test prompt")
    assert_contains "$response" "test" "Provider execution"
}
```

### Integration Tests

```bash
#!/bin/bash
# test/test-oauth-integration.sh

# Test full OAuth flow
test_oauth_flow() {
    # 1. Authenticate
    oauth_authenticate
    
    # 2. Verify token
    token=$(oauth_get_access_token)
    [[ -n "$token" ]] || fail "No token received"
    
    # 3. Test refresh
    oauth_refresh_token
    new_token=$(oauth_get_access_token)
    [[ "$new_token" != "$token" ]] || fail "Token not refreshed"
    
    # 4. Revoke tokens
    oauth_revoke_tokens
    
    # 5. Verify revocation
    oauth_status 2>/dev/null && fail "Tokens not revoked"
    
    echo "OAuth flow test passed"
}
```

## Debugging

### Enable Debug Mode

```bash
# Maximum verbosity
export OAUTH_DEBUG=true
export DEBUG_LEVEL=3

# Run with debug output
./hooks/lib/oauth-handler.sh authenticate 2>&1 | tee debug.log
```

### Common Debug Commands

```bash
# Check OAuth status
./hooks/lib/oauth-handler.sh status

# Validate configuration
./hooks/lib/oauth-handler.sh validate-config

# Test token refresh
./hooks/lib/oauth-handler.sh refresh

# Trace OAuth flow
strace -e trace=network ./hooks/lib/oauth-handler.sh authenticate
```

## Migration

### Migrating from API Key to OAuth

```bash
# 1. Backup current configuration
cp ~/.gemini-oddity/config.json config.backup.json

# 2. Run migration
./setup/interactive-setup.sh --migrate

# 3. Verify OAuth working
./test/test-oauth.sh

# 4. Remove API key
unset GEMINI_API_KEY
```

### Creating Custom Providers

To create a new provider:

1. Copy template: `cp hooks/providers/template-provider.sh hooks/providers/my-provider.sh`
2. Implement required functions
3. Add provider to configuration
4. Test with: `./test/test-provider.sh my-provider`

## Support

For API questions and issues:

1. Check function documentation in source files
2. Run tests to verify functionality
3. Enable debug mode for detailed output
4. Review example implementations
5. Open an issue with debug logs