#!/bin/bash
# ABOUTME: Unit tests for interactive setup wizard

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test helper
source "$TEST_DIR/../helpers/test-helper.sh"

# Test environment setup
export HOME="/tmp/test_home_$$"
export CONFIG_DIR="$HOME/.gemini-oddity"
export CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME"

# Source setup script functions (without running main)
source "$PROJECT_DIR/setup/interactive-setup.sh" 2>/dev/null

# Mock commands for testing
mock_gemini_cli() {
    gemini() {
        case "$1" in
            version)
                echo "gemini version 1.0.0-test"
                ;;
            auth)
                case "$2" in
                    print-access-token)
                        echo "mock-oauth-token-123456"
                        ;;
                    login)
                        echo "Authentication successful"
                        return 0
                        ;;
                esac
                ;;
            prompt)
                echo "Hello, setup test successful!"
                ;;
        esac
    }
    export -f gemini
}

mock_curl() {
    curl() {
        # Parse URL from arguments
        local url=""
        for arg in "$@"; do
            if [[ "$arg" == http* ]]; then
                url="$arg"
                break
            fi
        done
        
        # Return mock responses based on URL
        if [[ "$url" == *"/models"* ]]; then
            echo '{"models":[{"name":"gemini-1.5-flash","version":"001"}]}'
            return 0
        elif [[ "$url" == *":generateContent"* ]]; then
            echo '{"candidates":[{"content":{"parts":[{"text":"Hello, setup test successful!"}]}}]}'
            return 0
        fi
        
        return 1
    }
    export -f curl
}

# ============================================================================
# Environment Detection Tests
# ============================================================================

test_environment_detection() {
    test_start "Environment Detection"
    
    # Mock commands
    mock_gemini_cli
    mock_curl
    
    # Run environment detection
    local output=$(detect_environment 2>&1)
    local exit_code=$?
    
    # Check for expected outputs
    if echo "$output" | grep -q "Bash version:" && \
       echo "$output" | grep -q "Operating System:" && \
       echo "$output" | grep -q "Configuration directory: Writable"; then
        test_pass "Environment detection completed"
    else
        test_fail "Environment detection incomplete"
    fi
}

test_bash_version_check() {
    test_start "Bash Version Check"
    
    # Bash version should be >= 4.0
    local bash_major="${BASH_VERSION%%.*}"
    
    if [ "$bash_major" -ge 4 ]; then
        test_pass "Bash version $BASH_VERSION meets requirements"
    else
        test_fail "Bash version $BASH_VERSION too old"
    fi
}

test_os_detection() {
    test_start "OS Detection"
    
    local os_type="unknown"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        os_type="windows"
    fi
    
    if [ "$os_type" != "unknown" ]; then
        test_pass "OS detected: $os_type"
    else
        test_fail "OS detection failed: $OSTYPE"
    fi
}

test_directory_permissions() {
    test_start "Directory Permission Check"
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Test write permissions
    local test_file="$CONFIG_DIR/.permission_test_$$"
    
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        test_pass "Configuration directory writable"
    else
        test_fail "Configuration directory not writable"
    fi
}

# ============================================================================
# Authentication Configuration Tests
# ============================================================================

test_save_auth_config_api_key() {
    test_start "Save API Key Configuration"
    
    # Save API key configuration
    save_auth_config "api_key" "" "test-api-key-123" 2>&1 >/dev/null
    
    # Check if config file was created
    if [ -f "$CONFIG_DIR/config.json" ]; then
        # Check file permissions
        local perms=$(stat -c %a "$CONFIG_DIR/config.json" 2>/dev/null || stat -f %A "$CONFIG_DIR/config.json" 2>/dev/null)
        
        # Check if API key is in config
        if grep -q '"auth_type": "api_key"' "$CONFIG_DIR/config.json" && \
           grep -q '"api_key": "test-api-key-123"' "$CONFIG_DIR/config.json"; then
            test_pass "API key configuration saved correctly"
        else
            test_fail "API key not found in configuration"
        fi
    else
        test_fail "Configuration file not created"
    fi
}

test_save_auth_config_oauth() {
    test_start "Save OAuth Configuration"
    
    # Save OAuth configuration
    save_auth_config "oauth" "gemini" "client-id-456" "client-secret-789" 2>&1 >/dev/null
    
    # Check if config file was created
    if [ -f "$CONFIG_DIR/config.json" ]; then
        # Check if OAuth config is correct
        if grep -q '"auth_type": "oauth"' "$CONFIG_DIR/config.json" && \
           grep -q '"provider": "gemini"' "$CONFIG_DIR/config.json" && \
           grep -q '"client_id": "client-id-456"' "$CONFIG_DIR/config.json"; then
            test_pass "OAuth configuration saved correctly"
        else
            test_fail "OAuth configuration incorrect"
        fi
    else
        test_fail "Configuration file not created"
    fi
}

# ============================================================================
# Claude Integration Tests
# ============================================================================

test_update_claude_hooks_new_file() {
    test_start "Update Claude Hooks - New File"
    
    # Ensure Claude settings don't exist
    rm -f "$CLAUDE_SETTINGS"
    
    # Update hooks
    update_claude_hooks 2>&1 >/dev/null
    
    # Check if settings file was created
    if [ -f "$CLAUDE_SETTINGS" ]; then
        # Check if hook was added
        if grep -q "gemini-bridge.sh" "$CLAUDE_SETTINGS"; then
            test_pass "Claude hooks created and configured"
        else
            test_fail "Hook not added to Claude settings"
        fi
    else
        test_fail "Claude settings file not created"
    fi
}

test_update_claude_hooks_existing_file() {
    test_start "Update Claude Hooks - Existing File"
    
    # Create existing Claude settings
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{"existingKey": "value"}' > "$CLAUDE_SETTINGS"
    
    # Update hooks
    update_claude_hooks 2>&1 >/dev/null
    
    # Check if settings file still exists
    if [ -f "$CLAUDE_SETTINGS" ]; then
        # Check if existing key is preserved
        if grep -q '"existingKey": "value"' "$CLAUDE_SETTINGS" && \
           grep -q "gemini-bridge.sh" "$CLAUDE_SETTINGS"; then
            test_pass "Claude hooks updated while preserving existing settings"
        else
            test_fail "Existing settings lost or hook not added"
        fi
    else
        test_fail "Claude settings file disappeared"
    fi
}

test_claude_hooks_backup() {
    test_start "Claude Hooks Backup Creation"
    
    # Create Claude settings
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{"test": "data"}' > "$CLAUDE_SETTINGS"
    
    # Update hooks
    update_claude_hooks 2>&1 >/dev/null
    
    # Check for backup file
    if ls "${CLAUDE_SETTINGS}".backup.* >/dev/null 2>&1; then
        local backup_file=$(ls -t "${CLAUDE_SETTINGS}".backup.* | head -1)
        if [ -f "$backup_file" ]; then
            if grep -q '"test": "data"' "$backup_file"; then
                test_pass "Backup created with original content"
            else
                test_fail "Backup content incorrect"
            fi
        else
            test_fail "Backup file not readable"
        fi
    else
        test_fail "No backup file created"
    fi
}

# ============================================================================
# Configuration Testing Tests
# ============================================================================

test_configuration_validation() {
    test_start "Configuration Validation"
    
    # Mock gemini CLI
    mock_gemini_cli
    mock_curl
    
    # Set up minimal configuration
    mkdir -p "$CONFIG_DIR"
    export GEMINI_API_KEY="test-api-key"
    
    # Source provider
    source "$PROJECT_DIR/hooks/providers/gemini-cli-provider.sh" 2>/dev/null
    
    # Test configuration
    local output=$(test_configuration 2>&1)
    
    if echo "$output" | grep -q "Provider initialization successful"; then
        test_pass "Configuration validation works"
    else
        test_fail "Configuration validation failed"
    fi
}

test_api_connectivity_test() {
    test_start "API Connectivity Test"
    
    # Mock curl for API responses
    mock_curl
    
    # Set API key
    export GEMINI_API_KEY="test-api-key"
    
    # Source provider
    source "$PROJECT_DIR/hooks/providers/gemini-cli-provider.sh" 2>/dev/null
    
    # Test API call
    local response=$(gemini_cli_execute_request "generateContent" "Test prompt" 2>/dev/null)
    
    if [ -n "$response" ]; then
        test_pass "API connectivity test successful"
    else
        test_fail "API connectivity test failed"
    fi
}

# ============================================================================
# User Input Simulation Tests
# ============================================================================

test_prompt_functions() {
    test_start "Prompt Functions"
    
    # Test prompt_input with default
    local result=$(echo "" | prompt_input "Test prompt" "default_value")
    if [ "$result" = "default_value" ]; then
        test_pass "prompt_input handles defaults correctly"
    else
        test_fail "prompt_input default handling failed"
    fi
}

test_color_output_functions() {
    test_start "Color Output Functions"
    
    # Test color functions don't crash
    print_success "Test success" >/dev/null 2>&1
    local success_code=$?
    
    print_error "Test error" >/dev/null 2>&1
    local error_code=$?
    
    print_warning "Test warning" >/dev/null 2>&1
    local warning_code=$?
    
    print_info "Test info" >/dev/null 2>&1
    local info_code=$?
    
    if [ $success_code -eq 0 ] && [ $error_code -eq 0 ] && \
       [ $warning_code -eq 0 ] && [ $info_code -eq 0 ]; then
        test_pass "Color output functions work"
    else
        test_fail "Color output functions failed"
    fi
}

# ============================================================================
# Logging Tests
# ============================================================================

test_setup_logging() {
    test_start "Setup Logging"
    
    # Create log directory
    mkdir -p "$CONFIG_DIR"
    
    # Log a message
    log_message "Test log message"
    
    # Check if log file exists and contains message
    if [ -f "$CONFIG_DIR/setup.log" ]; then
        if grep -q "Test log message" "$CONFIG_DIR/setup.log"; then
            test_pass "Logging works correctly"
        else
            test_fail "Log message not found"
        fi
    else
        test_fail "Log file not created"
    fi
}

# ============================================================================
# Integration Test
# ============================================================================

test_full_setup_flow_simulation() {
    test_start "Full Setup Flow Simulation"
    
    # Mock all external commands
    mock_gemini_cli
    mock_curl
    
    # Create necessary directories
    mkdir -p "$CONFIG_DIR"
    
    # Simulate environment detection
    detect_environment >/dev/null 2>&1
    local env_result=$?
    
    # Simulate saving configuration
    save_auth_config "api_key" "" "test-key" >/dev/null 2>&1
    local save_result=$?
    
    # Simulate Claude hooks update
    update_claude_hooks >/dev/null 2>&1
    local hooks_result=$?
    
    # Check results
    if [ $env_result -eq 0 ] && [ $save_result -eq 0 ] && [ $hooks_result -eq 0 ]; then
        test_pass "Full setup flow simulation successful"
    else
        test_fail "Setup flow simulation failed"
    fi
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup_test_environment() {
    rm -rf "$HOME"
    unset -f gemini
    unset -f curl
}

# ============================================================================
# Run Tests
# ============================================================================

run_all_tests() {
    echo "Running Interactive Setup Wizard Tests"
    echo "======================================="
    
    # Environment Detection Tests
    echo ""
    echo "Environment Detection Tests:"
    test_environment_detection
    test_bash_version_check
    test_os_detection
    test_directory_permissions
    
    # Authentication Configuration Tests
    echo ""
    echo "Authentication Configuration Tests:"
    test_save_auth_config_api_key
    test_save_auth_config_oauth
    
    # Claude Integration Tests
    echo ""
    echo "Claude Integration Tests:"
    test_update_claude_hooks_new_file
    test_update_claude_hooks_existing_file
    test_claude_hooks_backup
    
    # Configuration Testing Tests
    echo ""
    echo "Configuration Testing Tests:"
    test_configuration_validation
    test_api_connectivity_test
    
    # User Input Tests
    echo ""
    echo "User Interface Tests:"
    test_prompt_functions
    test_color_output_functions
    
    # Logging Tests
    echo ""
    echo "Logging Tests:"
    test_setup_logging
    
    # Integration Test
    echo ""
    echo "Integration Tests:"
    test_full_setup_flow_simulation
    
    # Cleanup
    cleanup_test_environment
    
    # Summary
    test_summary
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi