#!/bin/bash
# ABOUTME: Comprehensive unit tests for enhanced configuration manager

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test helper
source "$TEST_DIR/../helpers/test-helper.sh" 2>/dev/null || true

# Mock environment for testing
export HOME="/tmp/test_home_$$"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Create test environment
mkdir -p "$HOME"

# Source the config manager
source "$PROJECT_DIR/hooks/lib/config-manager.sh"

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
# Setup and Teardown
# ============================================================================

setup_test_environment() {
    # Clean previous test data
    rm -rf "$HOME"
    mkdir -p "$HOME"
    
    # Re-initialize config system
    init_config
}

teardown_test_environment() {
    # Clean up
    secure_cleanup 2>/dev/null || true
    rm -rf "$HOME"
}

# ============================================================================
# TEST: XDG Directory Structure
# ============================================================================

test_xdg_directory_creation() {
    local test_name="XDG Directory Structure"
    
    setup_test_environment
    
    # Check if XDG directories were created
    if [ -d "$XDG_CONFIG_HOME/gemini-oddity" ] && \
       [ -d "$XDG_CONFIG_HOME/gemini-oddity/providers" ] && \
       [ -d "$XDG_CONFIG_HOME/gemini-oddity/auth" ] && \
       [ -d "$XDG_CACHE_HOME/gemini-oddity" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Default Configuration Creation
# ============================================================================

test_default_config_creation() {
    local test_name="Default Configuration Creation"
    
    setup_test_environment
    
    # Check if default config was created
    local config_file="$XDG_CONFIG_HOME/gemini-oddity/config.json"
    
    if [ -f "$config_file" ]; then
        # Validate JSON structure
        if validate_json "$config_file"; then
            # Check for required fields
            local has_version=$(grep -c '"version"' "$config_file")
            local has_global=$(grep -c '"global"' "$config_file")
            local has_providers=$(grep -c '"providers"' "$config_file")
            
            if [ $has_version -gt 0 ] && [ $has_global -gt 0 ] && [ $has_providers -gt 0 ]; then
                report_test "$test_name" "PASS"
            else
                report_test "$test_name" "FAIL"
            fi
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Loading and Validation
# ============================================================================

test_config_load_validation() {
    local test_name="Configuration Load and Validation"
    
    setup_test_environment
    
    # Create a test config
    local test_config="$HOME/test_config.json"
    cat > "$test_config" << 'EOF'
{
  "version": "1.0.0",
  "global": {
    "log_level": "debug",
    "cache_ttl": 7200
  }
}
EOF
    
    # Try to load config
    if load_config "$test_config"; then
        # Check if values were loaded
        local log_level=$(get_config "global.log_level")
        local cache_ttl=$(get_config "global.cache_ttl")
        
        if [ "$log_level" = "debug" ] && [ "$cache_ttl" = "7200" ]; then
            report_test "$test_name" "PASS"
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Get/Set Operations
# ============================================================================

test_config_get_set() {
    local test_name="Configuration Get/Set Operations"
    
    setup_test_environment
    
    # Set various config values
    set_config "test.key1" "value1"
    set_config "test.nested.key2" "value2"
    set_config "test.array[0]" "item1"
    
    # Get values back
    local val1=$(get_config "test.key1")
    local val2=$(get_config "test.nested.key2")
    local val3=$(get_config "test.array[0]")
    local val_default=$(get_config "nonexistent.key" "default_value")
    
    if [ "$val1" = "value1" ] && \
       [ "$val2" = "value2" ] && \
       [ "$val3" = "item1" ] && \
       [ "$val_default" = "default_value" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Secure Storage Encryption
# ============================================================================

test_secure_storage() {
    local test_name="Secure Storage Encryption"
    
    setup_test_environment
    
    # Store secure config
    store_secure_config "auth.api_key" "secret_key_123"
    store_secure_config "auth.client_secret" "secret_456"
    
    # Check if file was created with correct permissions
    local secure_file="$XDG_CONFIG_HOME/gemini-oddity/auth/secure.enc"
    if [ -f "$secure_file" ]; then
        local perms=$(stat -c %a "$secure_file" 2>/dev/null || stat -f %A "$secure_file" 2>/dev/null)
        
        # Load secure config
        load_secure_config
        
        # Verify we can retrieve decrypted values
        local api_key=$(get_config "auth.api_key")
        local client_secret=$(get_config "auth.client_secret")
        
        if [[ "$perms" == *"600"* ]] || [[ "$perms" == "600" ]]; then
            # If openssl is available, check encryption actually worked
            if command -v openssl &>/dev/null; then
                # Values should be decrypted properly
                if [ "$api_key" = "secret_key_123" ] && [ "$client_secret" = "secret_456" ]; then
                    report_test "$test_name" "PASS"
                else
                    report_test "$test_name" "FAIL"
                fi
            else
                # Without openssl, just check storage worked
                report_test "$test_name" "PASS"
            fi
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Environment Variable Overrides
# ============================================================================

test_env_overrides() {
    local test_name="Environment Variable Overrides"
    
    setup_test_environment
    
    # Set environment variables
    export CLAUDE_GEMINI_PROVIDER_TYPE="custom_provider"
    export CLAUDE_GEMINI_LOG_LEVEL="error"
    export GEMINI_API_KEY="env_api_key"
    export GOOGLE_CLIENT_ID="env_client_id"
    
    # Apply overrides
    apply_env_overrides
    
    # Check if overrides were applied
    local provider_type=$(get_env_config "provider.type")
    local log_level=$(get_env_config "log.level")
    local api_key=$(get_config "auth.gemini_api_key")
    local client_id=$(get_config "auth.google_client_id")
    
    if [ "$provider_type" = "custom_provider" ] && \
       [ "$log_level" = "error" ] && \
       [ "$api_key" = "env_api_key" ] && \
       [ "$client_id" = "env_client_id" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    # Clean up env vars
    unset CLAUDE_GEMINI_PROVIDER_TYPE
    unset CLAUDE_GEMINI_LOG_LEVEL
    unset GEMINI_API_KEY
    unset GOOGLE_CLIENT_ID
    
    teardown_test_environment
}

# ============================================================================
# TEST: Provider Configuration Management
# ============================================================================

test_provider_management() {
    local test_name="Provider Configuration Management"
    
    setup_test_environment
    
    # Register a provider
    local provider_config='{
  "name": "test-provider",
  "auth_type": "api_key",
  "api_key": "provider_key_123",
  "endpoint": "https://api.example.com"
}'
    
    if register_provider "test-provider" "$provider_config"; then
        # Update provider config
        update_provider_config "test-provider" "rate_limit" "100"
        
        # Get provider config
        local auth_type=$(get_provider_config "test-provider" "auth_type")
        local api_key=$(get_provider_config "test-provider" "api_key")
        local rate_limit=$(get_provider_config "test-provider" "rate_limit")
        
        # Validate provider config
        if validate_provider_config "test-provider"; then
            if [ "$auth_type" = "api_key" ] && \
               [ "$api_key" = "provider_key_123" ] && \
               [ "$rate_limit" = "100" ]; then
                report_test "$test_name" "PASS"
            else
                report_test "$test_name" "FAIL"
            fi
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Save and Reload
# ============================================================================

test_config_save_reload() {
    local test_name="Configuration Save and Reload"
    
    setup_test_environment
    
    # Set some config values
    set_config "test.save.key1" "save_value1"
    set_config "test.save.nested.key2" "save_value2"
    
    # Save configuration
    if save_config; then
        # Clear in-memory config
        CONFIG_DATA=()
        
        # Reload config
        if load_config; then
            # Check if values persist
            local val1=$(get_config "test.save.key1")
            local val2=$(get_config "test.save.nested.key2")
            
            if [ "$val1" = "save_value1" ] && [ "$val2" = "save_value2" ]; then
                report_test "$test_name" "PASS"
            else
                report_test "$test_name" "FAIL"
            fi
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Backup
# ============================================================================

test_config_backup() {
    local test_name="Configuration Backup"
    
    setup_test_environment
    
    # Create and save config
    set_config "backup.test" "original_value"
    save_config
    
    # Create backup
    local backup_file=$(backup_config)
    
    if [ -f "$backup_file" ]; then
        # Modify original
        set_config "backup.test" "modified_value"
        save_config
        
        # Check backup has original value
        local backup_content=$(cat "$backup_file")
        if echo "$backup_content" | grep -q "original_value"; then
            report_test "$test_name" "PASS"
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Merge
# ============================================================================

test_config_merge() {
    local test_name="Configuration Merge"
    
    setup_test_environment
    
    # Set base config
    set_config "base.key1" "base_value1"
    set_config "base.key2" "base_value2"
    save_config
    
    # Create merge file
    local merge_file="$HOME/merge_config.json"
    cat > "$merge_file" << 'EOF'
{
  "base": {
    "key2": "merged_value2",
    "key3": "merged_value3"
  }
}
EOF
    
    # Merge configuration
    if merge_config "$merge_file" "true"; then
        local val1=$(get_config "base.key1")
        local val2=$(get_config "base.key2")
        local val3=$(get_config "base.key3")
        
        if [ "$val1" = "base_value1" ] && \
           [ "$val2" = "merged_value2" ] && \
           [ "$val3" = "merged_value3" ]; then
            report_test "$test_name" "PASS"
        else
            report_test "$test_name" "FAIL"
        fi
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Legacy Migration
# ============================================================================

test_legacy_migration() {
    local test_name="Legacy Migration"
    
    # Set up legacy structure
    rm -rf "$HOME/.gemini-oddity" "$HOME/.config"
    mkdir -p "$HOME/.gemini-oddity/auth"
    
    # Create legacy config
    cat > "$HOME/.gemini-oddity/config" << 'EOF'
# Legacy configuration
api_key=legacy_api_key_123
log_level=warning
cache_ttl=1800
custom_setting=custom_value
EOF
    
    # Create legacy tokens
    cat > "$HOME/.gemini-oddity/auth/tokens.json" << 'EOF'
{
  "access_token": "legacy_token",
  "refresh_token": "legacy_refresh"
}
EOF
    
    # Initialize config system (should trigger migration)
    init_config
    
    # Check if migration worked
    load_secure_config
    
    local api_key=$(get_config "auth.api_key")
    local log_level=$(get_config "global.log_level")
    local cache_ttl=$(get_config "global.cache_ttl")
    local custom=$(get_config "legacy.custom_setting")
    
    # Check if tokens were migrated
    local tokens_file="$XDG_CONFIG_HOME/gemini-oddity/auth/tokens.json"
    
    if [ "$log_level" = "warning" ] && \
       [ "$cache_ttl" = "1800" ] && \
       [ "$custom" = "custom_value" ] && \
       [ -f "$tokens_file" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: File Permissions
# ============================================================================

test_file_permissions() {
    local test_name="File Permissions"
    
    setup_test_environment
    
    # Check directory permissions
    local config_dir="$XDG_CONFIG_HOME/gemini-oddity"
    local auth_dir="$config_dir/auth"
    
    local config_dir_perms=$(stat -c %a "$config_dir" 2>/dev/null || stat -f %A "$config_dir" 2>/dev/null)
    local auth_dir_perms=$(stat -c %a "$auth_dir" 2>/dev/null || stat -f %A "$auth_dir" 2>/dev/null)
    
    # Save config to check file permissions
    save_config
    local config_file="$config_dir/config.json"
    local config_file_perms=$(stat -c %a "$config_file" 2>/dev/null || stat -f %A "$config_file" 2>/dev/null)
    
    if [[ "$config_dir_perms" == *"700"* ]] && \
       [[ "$auth_dir_perms" == *"700"* ]] && \
       [[ "$config_file_perms" == *"600"* ]]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: JSON Schema Validation
# ============================================================================

test_schema_validation() {
    local test_name="JSON Schema Validation"
    
    setup_test_environment
    
    # Test valid schema
    local valid_config="$HOME/valid_config.json"
    cat > "$valid_config" << 'EOF'
{
  "version": "1.0.0",
  "global": {
    "log_level": "info"
  }
}
EOF
    
    # Test invalid schema (missing version)
    local invalid_config="$HOME/invalid_config.json"
    cat > "$invalid_config" << 'EOF'
{
  "global": {
    "log_level": "info"
  }
}
EOF
    
    local valid_result=false
    local invalid_result=false
    
    if validate_config_schema "$valid_config" 2>/dev/null; then
        valid_result=true
    fi
    
    if ! validate_config_schema "$invalid_config" 2>/dev/null; then
        invalid_result=true
    fi
    
    if [ "$valid_result" = true ] && [ "$invalid_result" = true ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Key Operations
# ============================================================================

test_config_key_operations() {
    local test_name="Configuration Key Operations"
    
    setup_test_environment
    
    # Set some keys
    set_config "ops.key1" "value1"
    set_config "ops.key2" "value2"
    set_config "ops.key3" "value3"
    
    # Check if key exists
    local has_key1=$(has_config "ops.key1")
    local has_key4=$(has_config "ops.key4")
    
    # Delete a key
    delete_config "ops.key2"
    local has_key2_after=$(has_config "ops.key2")
    
    # List keys
    local key_count=$(list_config_keys | grep -c "ops.key")
    
    if [ "$has_key1" = "true" ] && \
       [ "$has_key4" = "false" ] && \
       [ "$has_key2_after" = "false" ] && \
       [ "$key_count" -eq 2 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Configuration Reset
# ============================================================================

test_config_reset() {
    local test_name="Configuration Reset"
    
    setup_test_environment
    
    # Set custom config
    set_config "custom.key" "custom_value"
    set_config "global.log_level" "debug"
    
    # Reset to defaults
    reset_config
    
    # Check if custom key is gone and defaults are restored
    local custom_key=$(get_config "custom.key" "not_found")
    local log_level=$(get_config "global.log_level")
    
    if [ "$custom_key" = "not_found" ] && [ "$log_level" = "info" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

run_all_tests() {
    echo "Running Configuration Manager Tests..."
    echo "================================="
    
    test_xdg_directory_creation
    test_default_config_creation
    test_config_load_validation
    test_config_get_set
    test_secure_storage
    test_env_overrides
    test_provider_management
    test_config_save_reload
    test_config_backup
    test_config_merge
    test_legacy_migration
    test_file_permissions
    test_schema_validation
    test_config_key_operations
    test_config_reset
    
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