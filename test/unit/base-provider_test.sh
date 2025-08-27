#!/bin/bash
# ABOUTME: Unit tests for base provider interface

# Source test framework
source "$(dirname "$0")/../helpers/test-framework.sh"

# Source the file to be tested
source "$(dirname "$0")/../../hooks/providers/base-provider.sh"

describe "Base Provider Interface"

# Test provider registration
test_provider_registration() {
    # Clear any existing providers
    clear_providers
    
    # Mock provider
    local provider_name="test-provider"
    
    # Register provider
    register_provider "$provider_name" "test_provider_init"
    
    # Verify registration
    local registered=$(is_provider_registered "$provider_name")
    assert_equals "true" "$registered" "Provider should be registered"
}
it "should register a provider" test_provider_registration

# Test provider initialization
test_provider_initialization() {
    # Clear and register provider
    clear_providers
    
    # Mock provider init function
    test_provider_init() {
        echo "initialized"
        return 0
    }
    
    # Register the provider
    register_provider "test-provider" "test_provider_init"
    
    # Initialize provider
    local result=$(initialize_provider "test-provider")
    
    assert_equals "initialized" "$result" "Provider should initialize"
}
it "should initialize a provider" test_provider_initialization

# Test authentication method selection
test_auth_method_selection() {
    # Clear providers
    clear_providers
    
    # Set provider config
    set_provider_config "test-provider" "auth_method" "oauth"
    
    # Get auth method
    local auth_method=$(get_provider_auth_method "test-provider")
    
    assert_equals "oauth" "$auth_method" "Should return configured auth method"
}
it "should support auth method selection" test_auth_method_selection

# Test provider configuration
test_provider_configuration() {
    # Clear providers
    clear_providers
    
    # Test setting and getting config
    set_provider_config "test-provider" "api_endpoint" "https://api.example.com"
    
    local endpoint=$(get_provider_config "test-provider" "api_endpoint")
    
    assert_equals "https://api.example.com" "$endpoint" "Should store and retrieve config"
}
it "should handle provider configuration" test_provider_configuration

# Test provider validation
test_provider_validation() {
    # Clear providers
    clear_providers
    
    # Validate provider exists
    local valid=$(validate_provider "nonexistent")
    assert_equals "false" "$valid" "Nonexistent provider should be invalid"
    
    # Register and validate
    register_provider "valid-provider" "valid_init"
    
    valid=$(validate_provider "valid-provider")
    assert_equals "true" "$valid" "Registered provider should be valid"
}
it "should validate providers" test_provider_validation

# Test provider listing
test_list_providers() {
    # Clear providers first
    clear_providers
    
    # Register multiple providers
    register_provider "provider1" "init1"
    register_provider "provider2" "init2"
    
    # List providers
    local providers=$(list_providers)
    
    assert_contains "$providers" "provider1" "Should list provider1"
    assert_contains "$providers" "provider2" "Should list provider2"
}
it "should list registered providers" test_list_providers

# Test auth fallback mechanism
test_auth_fallback() {
    # Clear providers
    clear_providers
    
    # Configure provider with fallback
    set_provider_config "test-provider" "auth_method" "oauth"
    set_provider_config "test-provider" "fallback_auth" "api_key"
    
    # Get fallback auth method
    local fallback=$(get_provider_fallback_auth "test-provider")
    
    assert_equals "api_key" "$fallback" "Should return fallback auth method"
}
it "should support auth fallback" test_auth_fallback

# Test provider response formatting
test_response_formatting() {
    # Mock provider response
    local raw_response='{"text": "Hello from provider", "status": "success"}'
    
    # Format response
    local formatted=$(format_provider_response "$raw_response")
    
    assert_equals "Hello from provider" "$formatted" "Should format response correctly"
}
it "should format provider responses" test_response_formatting

# Test error handling
test_error_handling() {
    # Test with invalid provider
    local result=$(initialize_provider "" 2>&1 || echo "error")
    assert_contains "$result" "error" "Should handle empty provider name"
    
    # Test with missing init function
    register_provider "broken-provider" "nonexistent_init" 2>/dev/null || true
    result=$(initialize_provider "broken-provider" 2>&1 || echo "error")
    assert_contains "$result" "error" "Should handle missing init function"
}
it "should handle errors gracefully" test_error_handling

# Print test summary
source "$(dirname "$0")/../helpers/test-summary.sh"
print_test_summary