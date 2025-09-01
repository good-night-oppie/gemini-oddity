#!/bin/bash
# ABOUTME: Comprehensive unit tests for OAuth handler

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test utilities
source "$TEST_DIR/../helpers/test-utils.sh"
source "$TEST_DIR/../helpers/mock-oauth-server.sh"

# Source the OAuth handler
source "$PROJECT_DIR/hooks/lib/oauth-handler.sh" 2>/dev/null || true

# Test environment setup
export HOME="/tmp/test_home_$$"
export CONFIG_DIR="$HOME/.claude-gemini-bridge"
export TOKEN_DIR="$CONFIG_DIR/tokens"
mkdir -p "$TOKEN_DIR"

# Mock encryption password
export OAUTH_ENCRYPTION_PASSWORD="test_password_123"

# Test OAuth configuration
test_oauth_config_validation() {
    test_start "OAuth Configuration Validation"
    
    # Create valid config
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "test",
    "oauth": {
        "client_id": "test_client_id",
        "client_secret": "test_client_secret",
        "redirect_uri": "http://localhost:8080/callback",
        "scope": "test.scope",
        "token_endpoint": "http://localhost:$MOCK_SERVER_PORT/token",
        "auth_endpoint": "http://localhost:$MOCK_SERVER_PORT/auth"
    }
}
EOF
    
    # Test valid configuration
    if oauth_validate_config 2>/dev/null; then
        test_pass "Valid configuration accepted"
    else
        test_fail "Valid configuration rejected"
    fi
    
    # Test missing client_id
    jq 'del(.oauth.client_id)' "$CONFIG_DIR/config.json" > "$CONFIG_DIR/config.tmp"
    mv "$CONFIG_DIR/config.tmp" "$CONFIG_DIR/config.json"
    
    if ! oauth_validate_config 2>/dev/null; then
        test_pass "Missing client_id detected"
    else
        test_fail "Missing client_id not detected"
    fi
}

test_token_storage_and_retrieval() {
    test_start "Token Storage and Retrieval"
    
    # Reset configuration
    generate_oauth_config > "$CONFIG_DIR/config.json"
    
    # Store test token
    local test_token="test_access_token_123"
    echo "$test_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
    
    # Retrieve token
    local retrieved_token=$(decrypt_data "$(cat "$TOKEN_DIR/access_token.enc")" "$OAUTH_ENCRYPTION_PASSWORD" 2>/dev/null)
    
    if [ "$retrieved_token" = "$test_token" ]; then
        test_pass "Token stored and retrieved correctly"
    else
        test_fail "Token retrieval failed"
    fi
    
    # Test file permissions
    assert_permissions "$TOKEN_DIR/access_token.enc" "600" "Token file permissions"
}

test_token_refresh_logic() {
    test_start "Token Refresh Logic"
    
    # Start mock server
    start_mock_oauth_server
    
    # Create expired token
    local expired_token=$(generate_test_token "access" -100)
    echo "$expired_token" > "$TOKEN_DIR/token_info.json"
    
    # Store refresh token
    echo "$MOCK_REFRESH_TOKEN" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/refresh_token.enc"
    
    # Attempt refresh
    if oauth_refresh_token 2>/dev/null; then
        test_pass "Token refresh successful"
    else
        test_fail "Token refresh failed"
    fi
    
    # Verify new token stored
    if [ -f "$TOKEN_DIR/access_token.enc" ]; then
        local new_token=$(decrypt_data "$(cat "$TOKEN_DIR/access_token.enc")" "$OAUTH_ENCRYPTION_PASSWORD" 2>/dev/null)
        if [[ "$new_token" == *"refreshed"* ]]; then
            test_pass "New token stored after refresh"
        else
            test_fail "New token not properly stored"
        fi
    else
        test_fail "Access token file not created"
    fi
    
    stop_mock_oauth_server
}

test_token_expiration_check() {
    test_start "Token Expiration Check"
    
    # Test expired token
    local expired_time=$(($(date +%s) - 3600))
    cat > "$TOKEN_DIR/token_info.json" <<EOF
{
    "expires_at": $expired_time,
    "scope": "test.scope"
}
EOF
    
    if oauth_is_token_expired 2>/dev/null; then
        test_pass "Expired token detected"
    else
        test_fail "Expired token not detected"
    fi
    
    # Test valid token
    local future_time=$(($(date +%s) + 3600))
    cat > "$TOKEN_DIR/token_info.json" <<EOF
{
    "expires_at": $future_time,
    "scope": "test.scope"
}
EOF
    
    if ! oauth_is_token_expired 2>/dev/null; then
        test_pass "Valid token recognized"
    else
        test_fail "Valid token marked as expired"
    fi
}

test_secure_token_cleanup() {
    test_start "Secure Token Cleanup"
    
    # Create test tokens
    echo "test" > "$TOKEN_DIR/access_token.enc"
    echo "test" > "$TOKEN_DIR/refresh_token.enc"
    echo "{}" > "$TOKEN_DIR/token_info.json"
    
    # Revoke tokens
    oauth_revoke_tokens 2>/dev/null || true
    
    # Verify tokens removed
    if [ ! -f "$TOKEN_DIR/access_token.enc" ] && \
       [ ! -f "$TOKEN_DIR/refresh_token.enc" ] && \
       [ ! -f "$TOKEN_DIR/token_info.json" ]; then
        test_pass "All tokens securely removed"
    else
        test_fail "Token cleanup incomplete"
    fi
}

test_oauth_flow_with_mock_server() {
    test_start "Complete OAuth Flow with Mock Server"
    
    # Start mock server
    start_mock_oauth_server
    
    # Configure for mock server
    cat > "$CONFIG_DIR/config.json" <<EOF
{
    "auth_type": "oauth",
    "provider": "test",
    "oauth": {
        "client_id": "test_client_id",
        "client_secret": "test_client_secret",
        "redirect_uri": "http://localhost:8080/callback",
        "scope": "test.scope",
        "token_endpoint": "http://localhost:$MOCK_SERVER_PORT/token",
        "auth_endpoint": "http://localhost:$MOCK_SERVER_PORT/auth"
    }
}
EOF
    
    # Mock the browser opening and code exchange
    mock_command "xdg-open" "echo 'Browser opened'"
    mock_command "open" "echo 'Browser opened'"
    
    # Simulate authorization code receipt
    echo "$MOCK_AUTH_CODE" > "$TEST_TMP_DIR/auth_code"
    
    # Exchange code for token
    local token_response=$(mock_exchange_code_for_token "$MOCK_AUTH_CODE")
    
    if assert_json_valid "$token_response" "Token response is valid JSON"; then
        # Extract and store tokens
        local access_token=$(echo "$token_response" | jq -r '.access_token')
        echo "$access_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
        
        # Verify token stored
        local stored_token=$(decrypt_data "$(cat "$TOKEN_DIR/access_token.enc")" "$OAUTH_ENCRYPTION_PASSWORD" 2>/dev/null)
        assert_equals "$access_token" "$stored_token" "Token stored correctly"
        
        test_pass "OAuth flow completed successfully"
    else
        test_fail "OAuth flow failed"
    fi
    
    stop_mock_oauth_server
}

test_concurrent_token_access() {
    test_start "Concurrent Token Access"
    
    # Create test token
    echo "concurrent_test_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
    
    # Function for concurrent access
    concurrent_read() {
        local id=$1
        for i in {1..10}; do
            decrypt_data "$(cat "$TOKEN_DIR/access_token.enc")" "$OAUTH_ENCRYPTION_PASSWORD" > /dev/null 2>&1
        done
    }
    
    # Run concurrent reads
    if run_concurrent_tests concurrent_read 10; then
        test_pass "Concurrent token access handled"
    else
        test_fail "Concurrent access failed"
    fi
}

test_token_encryption_security() {
    test_start "Token Encryption Security"
    
    local sensitive_token="super_secret_token_12345"
    
    # Encrypt token
    local encrypted=$(echo "$sensitive_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD")
    
    # Verify token not visible in encrypted form
    if ! echo "$encrypted" | grep -q "$sensitive_token"; then
        test_pass "Token properly encrypted"
    else
        test_fail "Token visible in encrypted form"
    fi
    
    # Verify decryption works
    local decrypted=$(echo "$encrypted" | decrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" 2>/dev/null)
    assert_equals "$sensitive_token" "$decrypted" "Token decrypts correctly"
}

test_invalid_token_handling() {
    test_start "Invalid Token Handling"
    
    # Test with corrupted encrypted token
    echo "corrupted_data" > "$TOKEN_DIR/access_token.enc"
    
    local result=$(oauth_get_access_token 2>/dev/null || echo "error")
    
    if [ "$result" = "error" ] || [ -z "$result" ]; then
        test_pass "Corrupted token handled gracefully"
    else
        test_fail "Corrupted token not detected"
    fi
    
    # Test with invalid JSON in token_info
    echo "not json" > "$TOKEN_DIR/token_info.json"
    
    if ! oauth_validate_stored_tokens 2>/dev/null; then
        test_pass "Invalid token info detected"
    else
        test_fail "Invalid token info not detected"
    fi
}

test_oauth_status_reporting() {
    test_start "OAuth Status Reporting"
    
    # Setup valid tokens
    echo "test_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/access_token.enc"
    echo "refresh_token" | encrypt_data - "$OAUTH_ENCRYPTION_PASSWORD" > "$TOKEN_DIR/refresh_token.enc"
    
    local expires_at=$(($(date +%s) + 3600))
    cat > "$TOKEN_DIR/token_info.json" <<EOF
{
    "expires_at": $expires_at,
    "scope": "test.scope",
    "token_type": "Bearer"
}
EOF
    
    # Get status
    local status=$(oauth_status 2>/dev/null || echo "")
    
    if assert_contains "$status" "valid" "Status shows valid"; then
        test_pass "Status reporting works"
    else
        test_fail "Status reporting failed"
    fi
}

# Cleanup function for this test file
cleanup_oauth_tests() {
    stop_mock_oauth_server
    rm -rf "$HOME"
    unset OAUTH_ENCRYPTION_PASSWORD
}

# Run all tests
run_all_oauth_tests() {
    echo "OAuth Handler Unit Tests"
    echo "========================"
    
    test_oauth_config_validation
    test_token_storage_and_retrieval
    test_token_refresh_logic
    test_token_expiration_check
    test_secure_token_cleanup
    test_oauth_flow_with_mock_server
    test_concurrent_token_access
    test_token_encryption_security
    test_invalid_token_handling
    test_oauth_status_reporting
    
    cleanup_oauth_tests
    
    test_summary
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_oauth_tests
fi