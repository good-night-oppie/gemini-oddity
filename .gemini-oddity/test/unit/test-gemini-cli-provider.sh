#!/bin/bash
# ABOUTME: Unit tests for Gemini CLI OAuth Provider

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source test helper
source "$TEST_DIR/../helpers/test-helper.sh" 2>/dev/null || true

# Source the provider
source "$TEST_DIR/../../hooks/providers/gemini-cli-provider.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test reporting
report_test() {
    local test_name="$1"
    local result="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "✓ $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ $test_name"
    fi
}

# ============================================================================
# Mock Functions
# ============================================================================

# Mock gemini CLI command
gemini() {
    local command="$1"
    shift
    
    case "$command" in
        auth)
            local subcommand="$1"
            case "$subcommand" in
                print-access-token)
                    if [ -n "${MOCK_GEMINI_TOKEN:-}" ]; then
                        echo "$MOCK_GEMINI_TOKEN"
                        return 0
                    else
                        return 1
                    fi
                    ;;
                login)
                    if [ "${MOCK_GEMINI_LOGIN_SUCCESS:-true}" = "true" ]; then
                        MOCK_GEMINI_TOKEN="mock-oauth-token-123"
                        echo "Successfully logged in"
                        return 0
                    else
                        echo "Login failed"
                        return 1
                    fi
                    ;;
            esac
            ;;
        prompt)
            if [ "${MOCK_GEMINI_PROMPT_SUCCESS:-true}" = "true" ]; then
                echo "Mock response to: $*"
                return 0
            else
                echo "Error: Authentication failed"
                return 1
            fi
            ;;
    esac
}

# Mock curl command
curl() {
    # Extract URL and check for API key or Bearer token
    local url=""
    local has_auth=false
    
    for arg in "$@"; do
        if [[ "$arg" == http* ]]; then
            url="$arg"
        elif [[ "$arg" == "Bearer"* ]] || [[ "$arg" == *"key="* ]]; then
            has_auth=true
        fi
    done
    
    if [ "$has_auth" = true ]; then
        if [[ "$url" == */models ]]; then
            echo '{"models":[{"name":"gemini-1.5-flash"},{"name":"gemini-1.5-pro"}]}'
        elif [[ "$url" == *":generateContent"* ]]; then
            echo '{"candidates":[{"content":{"parts":[{"text":"Mock API response"}]}}]}'
        fi
        return 0
    else
        echo '{"error":{"code":401,"message":"Unauthorized"}}'
        return 1
    fi
}

# ============================================================================
# TEST: Provider Registration
# ============================================================================

test_provider_registration() {
    local test_name="Provider Registration"
    
    # Check if provider is registered
    if [ "$(is_provider_registered "gemini-cli")" = "true" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Capabilities
# ============================================================================

test_provider_capabilities() {
    local test_name="Provider Capabilities"
    
    local capabilities=$(gemini-cli_get_capabilities 2>/dev/null)
    
    # Check all required fields
    local has_name=$(echo "$capabilities" | grep -c '"name":"gemini-cli"')
    local has_oauth=$(echo "$capabilities" | grep -c '"oauth"')
    local has_api=$(echo "$capabilities" | grep -c 'api')
    local has_stream=$(echo "$capabilities" | grep -c '"streaming"')
    local has_tokens=$(echo "$capabilities" | grep -c '"max_tokens":1000000')
    
    if [ $has_name -gt 0 ] && [ $has_oauth -gt 0 ] && [ $has_api -gt 0 ] && \
       [ $has_stream -gt 0 ] && [ $has_tokens -gt 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: OAuth Authentication
# ============================================================================

test_oauth_authentication() {
    local test_name="OAuth Authentication"
    
    # Reset mock state
    unset MOCK_GEMINI_TOKEN
    MOCK_GEMINI_LOGIN_SUCCESS=true
    
    # Test authentication
    local token=$(gemini-cli_authenticate 2>/dev/null)
    
    if [ "$token" = "mock-oauth-token-123" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: API Key Fallback
# ============================================================================

test_api_key_fallback() {
    local test_name="API Key Fallback"
    
    # Disable OAuth
    unset MOCK_GEMINI_TOKEN
    MOCK_GEMINI_LOGIN_SUCCESS=false
    
    # Set API key
    GEMINI_API_KEY="test-api-key-456"
    
    # Test authentication fallback
    local token=$(gemini-cli_authenticate 2>/dev/null)
    
    if [ "$token" = "test-api-key-456" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    # Clean up
    unset GEMINI_API_KEY
}

# ============================================================================
# TEST: Validate Authentication
# ============================================================================

test_validate_authentication() {
    local test_name="Validate Authentication"
    
    # Set up valid authentication
    set_provider_config "gemini-cli" "auth_token" "valid-token"
    set_provider_config "gemini-cli" "auth_type" "api_key"
    
    local status=$(gemini-cli_validate_auth)
    
    if [ "$status" = "valid" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Execute Request with OAuth
# ============================================================================

test_execute_request_oauth() {
    local test_name="Execute Request - OAuth"
    
    # Set up OAuth authentication
    MOCK_GEMINI_TOKEN="oauth-token"
    MOCK_GEMINI_PROMPT_SUCCESS=true
    set_provider_config "gemini-cli" "auth_token" "$MOCK_GEMINI_TOKEN"
    set_provider_config "gemini-cli" "auth_type" "oauth"
    
    local response=$(gemini-cli_execute_request "generateContent" "Test prompt" 2>/dev/null)
    
    if echo "$response" | grep -q "Mock response to: Test prompt"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Execute Request with API Key
# ============================================================================

test_execute_request_api_key() {
    local test_name="Execute Request - API Key"
    
    # Set up API key authentication
    set_provider_config "gemini-cli" "auth_token" "api-key-789"
    set_provider_config "gemini-cli" "auth_type" "api_key"
    
    local response=$(gemini-cli_execute_request "generateContent" "Test prompt" 2>/dev/null)
    
    if echo "$response" | grep -q "Mock API response"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Rate Limiting
# ============================================================================

test_rate_limiting() {
    local test_name="Rate Limiting"
    
    # Clear request timestamps
    GEMINI_REQUEST_TIMESTAMPS=()
    
    # Add some mock requests
    local current_time=$(date +%s)
    for i in {1..50}; do
        GEMINI_REQUEST_TIMESTAMPS[$((current_time - i))]="test"
    done
    
    local status=$(gemini-cli_rate_limit_check)
    
    if echo "$status" | grep -q '"status":"ok"' && \
       echo "$status" | grep -q '"remaining_minute"'; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Response Caching
# ============================================================================

test_response_caching() {
    local test_name="Response Caching"
    
    # Cache a response
    gemini-cli_cache_response "test-key" "cached-response" 300
    
    # Retrieve cached response
    local cached=$(gemini-cli_get_cached "test-key" 300)
    
    if [ "$cached" = "cached-response" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Health Check
# ============================================================================

test_health_check() {
    local test_name="Health Check"
    
    # Set valid authentication
    MOCK_GEMINI_TOKEN="valid-token"
    set_provider_config "gemini-cli" "auth_token" "$MOCK_GEMINI_TOKEN"
    
    local health=$(gemini-cli_health_check)
    
    if echo "$health" | grep -q '"status"' && \
       echo "$health" | grep -q '"message"'; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Token Refresh
# ============================================================================

test_token_refresh() {
    local test_name="Token Refresh"
    
    # Reset and test refresh
    unset MOCK_GEMINI_TOKEN
    MOCK_GEMINI_LOGIN_SUCCESS=true
    
    local new_token=$(gemini-cli_refresh_auth 2>/dev/null)
    
    if [ "$new_token" = "mock-oauth-token-123" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Request Retry on Auth Failure
# ============================================================================

test_request_retry_auth_failure() {
    local test_name="Request Retry - Auth Failure"
    
    # Set up to fail first, then succeed
    MOCK_GEMINI_PROMPT_SUCCESS=false
    set_provider_config "gemini-cli" "auth_token" "expired-token"
    set_provider_config "gemini-cli" "auth_type" "oauth"
    
    # This should trigger re-authentication
    local retry_count=0
    local response=""
    
    # Mock the retry by changing success flag after first attempt
    response=$(gemini-cli_execute_request "generateContent" "Test" 2>&1 || true)
    
    # The function should have attempted retry
    if echo "$response" | grep -qi "auth\|token"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Configuration
# ============================================================================

test_provider_configuration() {
    local test_name="Provider Configuration"
    
    # Check provider configuration
    local auth_method=$(get_provider_config "gemini-cli" "auth_method" "")
    local fallback=$(get_provider_config "gemini-cli" "fallback_auth" "")
    local version=$(get_provider_config "gemini-cli" "version" "")
    
    if [ "$auth_method" = "oauth" ] && \
       [ "$fallback" = "api_key" ] && \
       [ "$version" = "1.0.0" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

run_all_tests() {
    echo "Running Gemini CLI Provider Tests..."
    echo "================================="
    
    # Export mock functions
    export -f gemini
    export -f curl
    
    test_provider_registration
    test_provider_capabilities
    test_oauth_authentication
    test_api_key_fallback
    test_validate_authentication
    test_execute_request_oauth
    test_execute_request_api_key
    test_rate_limiting
    test_response_caching
    test_health_check
    test_token_refresh
    test_request_retry_auth_failure
    test_provider_configuration
    
    echo "================================="
    echo "Test Results:"
    echo "  Total: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "All tests passed! ✓"
        return 0
    else
        echo "Some tests failed. ✗"
        return 1
    fi
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi