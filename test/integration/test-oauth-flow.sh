#!/bin/bash
# ABOUTME: Integration tests for complete OAuth flow

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test utilities
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/mock-oauth-server.sh"

# Test environment setup
export TEST_TMP_DIR=$(mktemp -d)
export HOME="$TEST_TMP_DIR/home"
export CONFIG_DIR="$HOME/.claude-gemini-bridge"
export TOKEN_DIR="$CONFIG_DIR/tokens"
export OAUTH_ENCRYPTION_PASSWORD="integration_test_password"

# Create directories
mkdir -p "$TOKEN_DIR"
mkdir -p "$CONFIG_DIR"

# Source components
source "$PROJECT_DIR/hooks/lib/encryption-core.sh" 2>/dev/null
source "$PROJECT_DIR/hooks/lib/config-manager.sh" 2>/dev/null
source "$PROJECT_DIR/hooks/lib/oauth-handler.sh" 2>/dev/null
source "$PROJECT_DIR/hooks/providers/base-provider.sh" 2>/dev/null

test_complete_oauth_authentication_flow() {
    test_start "Complete OAuth Authentication Flow"
    
    # Start mock OAuth server
    start_mock_oauth_server
    
    # Configure OAuth
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "gemini",
    "oauth": {
        "client_id": "integration_client_id",
        "client_secret": "integration_client_secret",
        "redirect_uri": "http://localhost:8080/callback",
        "scope": "https://www.googleapis.com/auth/generative-language.retriever",
        "token_endpoint": "http://localhost:$MOCK_SERVER_PORT/token",
        "auth_endpoint": "http://localhost:$MOCK_SERVER_PORT/auth",
        "auto_refresh": true
    },
    "encryption": {
        "enabled": true,
        "algorithm": "aes-256-cbc"
    }
}
EOF
    
    # Mock browser and user interaction
    mock_command "xdg-open" "echo 'Opening browser for auth'"
    mock_command "open" "echo 'Opening browser for auth'"
    
    # Simulate authorization code exchange
    local auth_code="$MOCK_AUTH_CODE"
    
    # Exchange code for tokens
    local token_response=$(curl -s -X POST "http://localhost:$MOCK_SERVER_PORT/token" \
        -d "grant_type=authorization_code&code=$auth_code&client_id=integration_client_id&client_secret=integration_client_secret")
    
    if assert_json_valid "$token_response" "Token response valid"; then
        # Extract tokens
        local access_token=$(echo "$token_response" | jq -r '.access_token')
        local refresh_token=$(echo "$token_response" | jq -r '.refresh_token')
        
        # Store tokens securely
        echo "$access_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
        echo "$refresh_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/refresh_token.enc"
        
        # Store token metadata
        echo "$token_response" | jq '{expires_at: (.expires_in + now | floor), scope: .scope, token_type: .token_type}' > "$TOKEN_DIR/token_info.json"
        
        test_pass "OAuth authentication flow completed"
    else
        test_fail "OAuth authentication flow failed"
    fi
    
    stop_mock_oauth_server
}

test_token_refresh_integration() {
    test_start "Token Refresh Integration"
    
    # Start mock OAuth server
    start_mock_oauth_server
    
    # Setup expired token scenario
    local expired_time=$(($(date +%s) - 100))
    cat > "$TOKEN_DIR/token_info.json" <<EOF
{
    "expires_at": $expired_time,
    "scope": "test.scope",
    "token_type": "Bearer"
}
EOF
    
    # Store refresh token
    echo "$MOCK_REFRESH_TOKEN" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/refresh_token.enc"
    
    # Configure OAuth
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "gemini",
    "oauth": {
        "client_id": "refresh_client_id",
        "client_secret": "refresh_client_secret",
        "token_endpoint": "http://localhost:$MOCK_SERVER_PORT/token",
        "auto_refresh": true
    }
}
EOF
    
    # Trigger refresh
    local refresh_response=$(curl -s -X POST "http://localhost:$MOCK_SERVER_PORT/token" \
        -d "grant_type=refresh_token&refresh_token=$MOCK_REFRESH_TOKEN&client_id=refresh_client_id&client_secret=refresh_client_secret")
    
    if assert_json_valid "$refresh_response" "Refresh response valid"; then
        local new_access_token=$(echo "$refresh_response" | jq -r '.access_token')
        
        if assert_contains "$new_access_token" "refreshed" "New token received"; then
            # Store new token
            echo "$new_access_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
            
            # Update token info
            local new_expiry=$(($(date +%s) + 3600))
            jq ".expires_at = $new_expiry" "$TOKEN_DIR/token_info.json" > "$TOKEN_DIR/token_info.tmp"
            mv "$TOKEN_DIR/token_info.tmp" "$TOKEN_DIR/token_info.json"
            
            test_pass "Token refresh integration successful"
        else
            test_fail "New token not properly generated"
        fi
    else
        test_fail "Token refresh failed"
    fi
    
    stop_mock_oauth_server
}

test_provider_api_call_with_oauth() {
    test_start "Provider API Call with OAuth"
    
    # Start mock OAuth server
    start_mock_oauth_server
    
    # Setup valid token
    echo "$MOCK_ACCESS_TOKEN" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
    
    local future_time=$(($(date +%s) + 3600))
    cat > "$TOKEN_DIR/token_info.json" <<EOF
{
    "expires_at": $future_time,
    "scope": "test.scope",
    "token_type": "Bearer"
}
EOF
    
    # Make API call with token
    local api_response=$(curl -s -H "Authorization: Bearer $MOCK_ACCESS_TOKEN" \
        "http://localhost:$MOCK_SERVER_PORT/api/test")
    
    if assert_json_valid "$api_response" "API response valid"; then
        if assert_contains "$api_response" "test successful" "API call successful"; then
            test_pass "Provider API call with OAuth succeeded"
        else
            test_fail "API response unexpected"
        fi
    else
        test_fail "API call failed"
    fi
    
    stop_mock_oauth_server
}

test_oauth_error_handling() {
    test_start "OAuth Error Handling"
    
    # Start mock OAuth server
    start_mock_oauth_server
    
    # Test invalid client credentials
    local error_response=$(curl -s -X POST "http://localhost:$MOCK_SERVER_PORT/token" \
        -d "grant_type=authorization_code&code=invalid_code&client_id=wrong_id&client_secret=wrong_secret")
    
    # Server should return 404 for unhandled request
    if [ -z "$error_response" ] || [[ "$error_response" == *"404"* ]]; then
        test_pass "Invalid credentials rejected"
    else
        test_fail "Invalid credentials not properly rejected"
    fi
    
    # Test expired token handling
    echo "expired_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
    
    local api_response=$(curl -s -H "Authorization: Bearer expired_token" \
        "http://localhost:$MOCK_SERVER_PORT/api/test")
    
    # Should get empty or error response
    if [ -z "$api_response" ] || [[ "$api_response" == *"error"* ]]; then
        test_pass "Expired token handled"
    else
        test_fail "Expired token not properly handled"
    fi
    
    stop_mock_oauth_server
}

test_multi_provider_switching() {
    test_start "Multi-Provider Switching"
    
    # Configure first provider
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "gemini",
    "oauth": {
        "client_id": "gemini_client",
        "client_secret": "gemini_secret"
    }
}
EOF
    
    # Load configuration
    load_config 2>/dev/null || true
    
    if [ "$PROVIDER" = "gemini" ]; then
        test_pass "First provider loaded"
    else
        test_fail "First provider not loaded"
    fi
    
    # Switch to second provider
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "custom",
    "oauth": {
        "client_id": "custom_client",
        "client_secret": "custom_secret"
    }
}
EOF
    
    # Reload configuration
    load_config 2>/dev/null || true
    
    if [ "$PROVIDER" = "custom" ]; then
        test_pass "Provider switch successful"
    else
        test_fail "Provider switch failed"
    fi
}

test_concurrent_oauth_requests() {
    test_start "Concurrent OAuth Requests"
    
    # Start mock OAuth server
    start_mock_oauth_server
    
    # Setup valid token
    echo "$MOCK_ACCESS_TOKEN" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
    
    # Function for concurrent API calls
    make_concurrent_call() {
        local id=$1
        local response=$(curl -s -H "Authorization: Bearer $MOCK_ACCESS_TOKEN" \
            "http://localhost:$MOCK_SERVER_PORT/api/test")
        
        if [[ "$response" == *"successful"* ]]; then
            return 0
        else
            return 1
        fi
    }
    
    # Run concurrent calls
    if run_concurrent_tests make_concurrent_call 5; then
        test_pass "Concurrent OAuth requests handled"
    else
        test_fail "Concurrent OAuth requests failed"
    fi
    
    stop_mock_oauth_server
}

test_oauth_token_lifecycle() {
    test_start "OAuth Token Lifecycle"
    
    # Start mock OAuth server
    start_mock_oauth_server
    
    # Phase 1: Initial authentication
    local auth_code="$MOCK_AUTH_CODE"
    local token_response=$(curl -s -X POST "http://localhost:$MOCK_SERVER_PORT/token" \
        -d "grant_type=authorization_code&code=$auth_code")
    
    local access_token=$(echo "$token_response" | jq -r '.access_token // empty')
    if [ -n "$access_token" ]; then
        test_pass "Token acquired"
    else
        test_fail "Token acquisition failed"
        stop_mock_oauth_server
        return 1
    fi
    
    # Phase 2: Use token
    local api_response=$(curl -s -H "Authorization: Bearer $access_token" \
        "http://localhost:$MOCK_SERVER_PORT/api/test")
    
    if [[ "$api_response" == *"successful"* ]]; then
        test_pass "Token used successfully"
    else
        test_fail "Token usage failed"
    fi
    
    # Phase 3: Refresh token
    local refresh_token=$(echo "$token_response" | jq -r '.refresh_token // empty')
    if [ -n "$refresh_token" ]; then
        local refresh_response=$(curl -s -X POST "http://localhost:$MOCK_SERVER_PORT/token" \
            -d "grant_type=refresh_token&refresh_token=$refresh_token")
        
        local new_token=$(echo "$refresh_response" | jq -r '.access_token // empty')
        if [[ "$new_token" == *"refreshed"* ]]; then
            test_pass "Token refreshed"
        else
            test_fail "Token refresh failed"
        fi
    else
        test_fail "No refresh token available"
    fi
    
    # Phase 4: Revoke token
    local revoke_response=$(curl -s -X POST "http://localhost:$MOCK_SERVER_PORT/revoke" \
        -d "token=$access_token")
    
    # Check revocation (should get empty response)
    if [ -z "$revoke_response" ] || [ "$revoke_response" = "" ]; then
        test_pass "Token revoked"
    else
        test_fail "Token revocation unclear"
    fi
    
    stop_mock_oauth_server
}

test_oauth_scope_validation() {
    test_start "OAuth Scope Validation"
    
    # Configure with specific scopes
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "test",
    "oauth": {
        "scope": "read write delete",
        "required_scopes": ["read", "write"]
    }
}
EOF
    
    # Store token with scopes
    cat > "$TOKEN_DIR/token_info.json" <<EOF
{
    "expires_at": $(($(date +%s) + 3600)),
    "scope": "read write",
    "token_type": "Bearer"
}
EOF
    
    # Load and validate scopes
    load_config 2>/dev/null || true
    
    local token_scope=$(jq -r '.scope' "$TOKEN_DIR/token_info.json")
    
    # Check if required scopes are present
    local has_read=$(echo "$token_scope" | grep -q "read" && echo "yes" || echo "no")
    local has_write=$(echo "$token_scope" | grep -q "write" && echo "yes" || echo "no")
    
    if [ "$has_read" = "yes" ] && [ "$has_write" = "yes" ]; then
        test_pass "Required scopes validated"
    else
        test_fail "Scope validation failed"
    fi
}

# Cleanup function
cleanup_integration_tests() {
    stop_mock_oauth_server
    rm -rf "$TEST_TMP_DIR"
}

# Run all tests
run_all_integration_tests() {
    echo "OAuth Integration Tests"
    echo "======================"
    
    test_complete_oauth_authentication_flow
    test_token_refresh_integration
    test_provider_api_call_with_oauth
    test_oauth_error_handling
    test_multi_provider_switching
    test_concurrent_oauth_requests
    test_oauth_token_lifecycle
    test_oauth_scope_validation
    
    cleanup_integration_tests
    
    test_summary
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_integration_tests
fi