#!/bin/bash
# ABOUTME: Unit tests for base provider interface

# Source test helper
source "$(dirname "$0")/../helpers/test-helper.sh"

# Source the base provider
source "$(dirname "$0")/../../hooks/providers/base-provider.sh"

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
# TEST: Provider Registration
# ============================================================================

test_provider_registration() {
    local test_name="Provider Registration"
    
    # Clear providers first
    init_provider_system
    
    # Define a mock init function
    mock_provider_init() {
        echo "Mock provider initialized"
        return 0
    }
    
    # Register a provider
    register_provider "mock_provider" "mock_provider_init"
    local result=$?
    
    if [ $result -eq 0 ] && [ "$(is_provider_registered "mock_provider")" = "true" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Initialization
# ============================================================================

test_provider_initialization() {
    local test_name="Provider Initialization"
    
    # Clear providers first
    init_provider_system
    
    # Define a mock init function
    mock_provider_init() {
        echo "Mock provider initialized"
        return 0
    }
    
    # Register and initialize
    register_provider "mock_provider" "mock_provider_init"
    local output=$(initialize_provider "mock_provider" 2>&1)
    
    if echo "$output" | grep -q "Mock provider initialized"; then
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
    
    # Set configuration
    set_provider_config "test_provider" "api_key" "test123"
    set_provider_config "test_provider" "endpoint" "https://api.test.com"
    
    # Get configuration
    local api_key=$(get_provider_config "test_provider" "api_key")
    local endpoint=$(get_provider_config "test_provider" "endpoint")
    local missing=$(get_provider_config "test_provider" "missing" "default_value")
    
    if [ "$api_key" = "test123" ] && [ "$endpoint" = "https://api.test.com" ] && [ "$missing" = "default_value" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Auth Method
# ============================================================================

test_provider_auth_method() {
    local test_name="Provider Auth Method"
    
    # Set auth method
    set_provider_config "oauth_provider" "auth_method" "oauth"
    set_provider_config "api_provider" "auth_method" "api_key"
    
    # Get auth methods
    local oauth_method=$(get_provider_auth_method "oauth_provider")
    local api_method=$(get_provider_auth_method "api_provider")
    local default_method=$(get_provider_auth_method "unknown_provider")
    
    if [ "$oauth_method" = "oauth" ] && [ "$api_method" = "api_key" ] && [ "$default_method" = "api_key" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: List Providers
# ============================================================================

test_list_providers() {
    local test_name="List Providers"
    
    # Clear and register multiple providers
    init_provider_system
    
    register_provider "provider_a" "init_a"
    register_provider "provider_b" "init_b"
    register_provider "provider_c" "init_c"
    
    local providers=$(list_providers)
    
    if echo "$providers" | grep -q "provider_a" && \
       echo "$providers" | grep -q "provider_b" && \
       echo "$providers" | grep -q "provider_c"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Factory - Get Provider
# ============================================================================

test_get_provider() {
    local test_name="Provider Factory - Get Provider"
    
    # Clear and setup
    init_provider_system
    
    # Register providers with different auth methods
    register_provider "gemini_oauth" "init_gemini"
    set_provider_config "gemini_oauth" "auth_method" "oauth"
    
    register_provider "openai_api" "init_openai"
    set_provider_config "openai_api" "auth_method" "api_key"
    
    # Test direct provider name
    local direct=$(get_provider "gemini_oauth")
    
    # Test by auth type
    local by_oauth=$(get_provider "oauth")
    local by_api=$(get_provider "api_key")
    
    if [ "$direct" = "gemini_oauth" ] && [ "$by_oauth" = "gemini_oauth" ] && [ "$by_api" = "openai_api" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Interface Methods
# ============================================================================

test_provider_interface_methods() {
    local test_name="Provider Interface Methods"
    
    # Define mock provider implementation
    test_provider_authenticate() {
        echo "authenticated"
        return 0
    }
    
    test_provider_execute_request() {
        echo "request_executed"
        return 0
    }
    
    test_provider_validate_auth() {
        echo "valid"
        return 0
    }
    
    test_provider_get_capabilities() {
        echo '{"model":"test","max_tokens":1000}'
        return 0
    }
    
    # Test required methods
    local auth_result=$(provider_authenticate "test_provider" "test_data")
    local exec_result=$(provider_execute_request "test_provider" "endpoint" "data")
    local validate_result=$(provider_validate_auth "test_provider")
    local capabilities=$(provider_get_capabilities "test_provider")
    
    if [ "$auth_result" = "authenticated" ] && \
       [ "$exec_result" = "request_executed" ] && \
       [ "$validate_result" = "valid" ] && \
       echo "$capabilities" | grep -q '"model":"test"'; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Optional Provider Methods
# ============================================================================

test_optional_provider_methods() {
    local test_name="Optional Provider Methods"
    
    # Define optional method implementation
    test_opt_refresh_auth() {
        echo "refreshed_token"
        return 0
    }
    
    test_opt_cache_response() {
        echo "cached"
        return 0
    }
    
    test_opt_rate_limit_check() {
        echo '{"status":"ok","remaining":100}'
        return 0
    }
    
    # Test optional methods
    local refresh=$(provider_refresh_auth "test_opt")
    local cache=$(provider_cache_response "test_opt" "key" "value" "300")
    local rate_limit=$(provider_rate_limit_check "test_opt")
    
    if [ "$refresh" = "refreshed_token" ] && \
       [ "$cache" = "cached" ] && \
       echo "$rate_limit" | grep -q '"status":"ok"'; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Selection
# ============================================================================

test_provider_selection() {
    local test_name="Provider Selection"
    
    # Clear and setup providers
    init_provider_system
    
    # Register good provider
    register_provider "good_provider" "init_good"
    
    good_provider_validate_auth() {
        echo "valid"
        return 0
    }
    
    good_provider_get_capabilities() {
        echo '{"streaming":true,"max_tokens":1000000}'
        return 0
    }
    
    good_provider_rate_limit_check() {
        echo '{"status":"ok"}'
        return 0
    }
    
    # Register limited provider
    register_provider "limited_provider" "init_limited"
    
    limited_provider_validate_auth() {
        echo "invalid"
        return 1
    }
    
    limited_provider_get_capabilities() {
        echo '{"max_tokens":1000}'
        return 0
    }
    
    # Select best provider
    local best=$(select_best_provider '{"streaming":true}')
    
    if [ "$best" = "good_provider" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Provider Instance Creation
# ============================================================================

test_create_provider_instance() {
    local test_name="Provider Instance Creation"
    
    # Clear providers
    init_provider_system
    
    # Define init function
    test_instance_init() {
        echo "instance_initialized"
        return 0
    }
    
    # Register provider
    register_provider "test_instance" "test_instance_init"
    
    # Create instance
    local output=$(create_provider_instance "test_instance" 2>&1)
    
    if echo "$output" | grep -q "instance_initialized"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Error Handling - Missing Provider
# ============================================================================

test_missing_provider_error() {
    local test_name="Error Handling - Missing Provider"
    
    # Clear providers
    init_provider_system
    
    # Try to use non-existent provider
    local auth_error=$(provider_authenticate "nonexistent" 2>&1)
    local exec_error=$(provider_execute_request "nonexistent" 2>&1)
    
    if echo "$auth_error" | grep -q "Error.*must implement" && \
       echo "$exec_error" | grep -q "Error.*must implement"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Fallback Provider
# ============================================================================

test_fallback_provider() {
    local test_name="Fallback Provider"
    
    # Setup providers with fallback
    init_provider_system
    
    register_provider "primary" "init_primary"
    register_provider "fallback" "init_fallback"
    
    set_provider_config "primary" "fallback_provider" "fallback"
    
    # Primary fails, fallback succeeds
    primary_execute_request() {
        return 1  # Fail
    }
    
    fallback_execute_request() {
        echo "fallback_success"
        return 0
    }
    
    # Execute with fallback
    local result=$(execute_provider_method "primary" "execute_request" "test")
    
    if [ "$result" = "fallback_success" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

run_all_tests() {
    echo "Running Base Provider Tests..."
    echo "================================="
    
    test_provider_registration
    test_provider_initialization
    test_provider_configuration
    test_provider_auth_method
    test_list_providers
    test_get_provider
    test_provider_interface_methods
    test_optional_provider_methods
    test_provider_selection
    test_create_provider_instance
    test_missing_provider_error
    test_fallback_provider
    
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