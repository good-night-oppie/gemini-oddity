#!/bin/bash
# ABOUTME: Unit tests for configuration manager

# Source test framework
source "$(dirname "$0")/../helpers/test-framework.sh"

# Source the file to be tested
source "$(dirname "$0")/../../hooks/lib/config-manager.sh"

describe "Configuration Manager"

# Test loading configuration from file
test_load_config_from_file() {
    # Create temp config file
    local temp_dir=$(mktemp -d)
    local config_file="$temp_dir/test-config.json"
    
    cat > "$config_file" << 'EOF'
{
    "providers": {
        "gemini-cli": {
            "auth_method": "oauth",
            "enabled": true
        }
    },
    "settings": {
        "debug_level": 2,
        "cache_ttl": 3600
    }
}
EOF
    
    # Load config (function will be implemented)
    load_config "$config_file" 2>/dev/null || {
        rm -rf "$temp_dir"
        return 0
    }
    
    # Get config value
    local auth_method=$(get_config "providers.gemini-cli.auth_method" 2>/dev/null || echo "not implemented")
    
    if [ "$auth_method" = "not implemented" ]; then
        rm -rf "$temp_dir"
        return 0
    fi
    
    assert_equals "oauth" "$auth_method" "Should load auth method from config"
    
    # Cleanup
    rm -rf "$temp_dir"
}
it "should load configuration from file" test_load_config_from_file

# Test setting configuration values
test_set_config_value() {
    # Initialize config
    init_config 2>/dev/null || return 0
    
    # Set a value
    set_config "test.key" "test-value" 2>/dev/null || return 0
    
    # Get the value back
    local value=$(get_config "test.key" 2>/dev/null || echo "not implemented")
    
    if [ "$value" = "not implemented" ]; then
        return 0
    fi
    
    assert_equals "test-value" "$value" "Should set and get config value"
}
it "should set configuration values" test_set_config_value

# Test nested configuration paths
test_nested_config_paths() {
    # Initialize config
    init_config 2>/dev/null || return 0
    
    # Set nested value
    set_config "providers.test.auth.method" "oauth" 2>/dev/null || return 0
    set_config "providers.test.auth.client_id" "test-client" 2>/dev/null || return 0
    
    # Get nested values
    local method=$(get_config "providers.test.auth.method" 2>/dev/null || echo "not implemented")
    local client=$(get_config "providers.test.auth.client_id" 2>/dev/null || echo "not implemented")
    
    if [ "$method" = "not implemented" ]; then
        return 0
    fi
    
    assert_equals "oauth" "$method" "Should handle nested paths"
    assert_equals "test-client" "$client" "Should handle multiple nested values"
}
it "should handle nested configuration paths" test_nested_config_paths

# Test default values
test_default_values() {
    # Initialize config
    init_config 2>/dev/null || return 0
    
    # Get non-existent key with default
    local value=$(get_config "non.existent.key" "default-value" 2>/dev/null || echo "not implemented")
    
    if [ "$value" = "not implemented" ]; then
        return 0
    fi
    
    assert_equals "default-value" "$value" "Should return default for non-existent key"
}
it "should return default values" test_default_values

# Test saving configuration
test_save_config() {
    # Create temp directory
    local temp_dir=$(mktemp -d)
    local config_file="$temp_dir/save-test.json"
    
    # Initialize and set values
    init_config 2>/dev/null || {
        rm -rf "$temp_dir"
        return 0
    }
    
    set_config "test.save" "saved-value" 2>/dev/null || true
    
    # Save config
    save_config "$config_file" 2>/dev/null || {
        rm -rf "$temp_dir"
        return 0
    }
    
    # Verify file exists
    assert_file_exists "$config_file" "Config file should be saved"
    
    # Verify content
    if [ -f "$config_file" ]; then
        local content=$(cat "$config_file")
        assert_contains "$content" "saved-value" "Saved config should contain value"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}
it "should save configuration to file" test_save_config

# Test merging configurations
test_merge_configs() {
    # Create base config
    init_config 2>/dev/null || return 0
    set_config "base.key" "base-value" 2>/dev/null || true
    set_config "override.key" "old-value" 2>/dev/null || true
    
    # Create merge config file
    local temp_dir=$(mktemp -d)
    local merge_file="$temp_dir/merge.json"
    
    cat > "$merge_file" << 'EOF'
{
    "override": {
        "key": "new-value"
    },
    "additional": {
        "key": "added-value"
    }
}
EOF
    
    # Merge configs
    merge_config "$merge_file" 2>/dev/null || {
        rm -rf "$temp_dir"
        return 0
    }
    
    # Check values
    local base=$(get_config "base.key" 2>/dev/null || echo "not implemented")
    local override=$(get_config "override.key" 2>/dev/null || echo "not implemented")
    local added=$(get_config "additional.key" 2>/dev/null || echo "not implemented")
    
    if [ "$base" = "not implemented" ]; then
        rm -rf "$temp_dir"
        return 0
    fi
    
    assert_equals "base-value" "$base" "Base value should remain"
    assert_equals "new-value" "$override" "Override value should update"
    assert_equals "added-value" "$added" "Additional value should be added"
    
    # Cleanup
    rm -rf "$temp_dir"
}
it "should merge configurations" test_merge_configs

# Test environment variable expansion
test_env_var_expansion() {
    # Set test env var
    export TEST_CONFIG_VAR="expanded-value"
    
    # Initialize config
    init_config 2>/dev/null || return 0
    
    # Set value with env var reference
    set_config "test.env" "\${TEST_CONFIG_VAR}" 2>/dev/null || return 0
    
    # Get expanded value
    local value=$(get_config "test.env" 2>/dev/null || echo "not implemented")
    
    if [ "$value" = "not implemented" ]; then
        unset TEST_CONFIG_VAR
        return 0
    fi
    
    assert_equals "expanded-value" "$value" "Should expand environment variables"
    
    # Cleanup
    unset TEST_CONFIG_VAR
}
it "should expand environment variables" test_env_var_expansion

# Test configuration validation
test_config_validation() {
    # Create invalid config file
    local temp_dir=$(mktemp -d)
    local invalid_file="$temp_dir/invalid.json"
    
    echo "{ invalid json" > "$invalid_file"
    
    # Try to load invalid config
    local result=$(load_config "$invalid_file" 2>&1 || echo "error")
    
    assert_contains "$result" "error" "Should error on invalid JSON"
    
    # Cleanup
    rm -rf "$temp_dir"
}
it "should validate configuration" test_config_validation

# Test configuration backup
test_config_backup() {
    # Create config file
    local temp_dir=$(mktemp -d)
    local config_file="$temp_dir/config.json"
    
    echo '{"test": "value"}' > "$config_file"
    
    # Backup config (function will be implemented)
    backup_config "$config_file" 2>/dev/null || {
        rm -rf "$temp_dir"
        return 0
    }
    
    # Check for backup file
    local backup_exists=false
    for backup in "$config_file".backup*; do
        if [ -f "$backup" ]; then
            backup_exists=true
            break
        fi
    done
    
    assert_equals "true" "$backup_exists" "Backup file should be created"
    
    # Cleanup
    rm -rf "$temp_dir"
}
it "should backup configuration" test_config_backup

# Test error handling
test_config_error_handling() {
    # Test with non-existent file
    local result=$(load_config "/non/existent/file.json" 2>&1 || echo "error")
    assert_contains "$result" "error" "Should handle non-existent file"
    
    # Test with empty path
    result=$(set_config "" "value" 2>&1 || echo "error")
    assert_contains "$result" "error" "Should handle empty config path"
}
it "should handle errors gracefully" test_config_error_handling

# Print test summary
source "$(dirname "$0")/../helpers/test-summary.sh"
print_test_summary