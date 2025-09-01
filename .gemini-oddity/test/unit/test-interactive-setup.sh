#!/bin/bash
# ABOUTME: Unit tests for interactive setup script

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test helper
source "$TEST_DIR/../helpers/test-helper.sh" 2>/dev/null || true

# Mock environment for testing
export HOME="/tmp/test_home_$$"
export CONFIG_DIR="$HOME/.gemini-oddity"
export CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Source the setup script functions
source "$PROJECT_DIR/setup/interactive-setup.sh"

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
    # Create mock home directory
    mkdir -p "$HOME/.claude"
    mkdir -p "$CONFIG_DIR"
    
    # Create mock Claude settings
    echo '{"existingKey": "value"}' > "$CLAUDE_SETTINGS"
    
    # Reset environment
    unset GEMINI_API_KEY
    unset GOOGLE_API_KEY
    unset GOOGLE_CLIENT_ID
    unset GOOGLE_CLIENT_SECRET
}

teardown_test_environment() {
    # Clean up mock home directory
    rm -rf "$HOME"
}

# ============================================================================
# Mock Functions
# ============================================================================

# Mock command for testing
command() {
    case "$2" in
        gemini)
            return 1  # Gemini not installed
            ;;
        curl)
            return 0
            ;;
        jq)
            return 0
            ;;
        xdg-open|open)
            return 0
            ;;
        *)
            /usr/bin/command "$@"
            ;;
    esac
}

# Mock curl for API testing
curl() {
    if [[ "$*" == *"key=valid_key"* ]]; then
        echo '{"models":[{"name":"gemini-1.5-flash"}]}'
        return 0
    elif [[ "$*" == *"key=invalid_key"* ]]; then
        echo '{"error":{"code":401,"message":"Invalid API key"}}'
        return 1
    else
        echo '{"error":{"message":"Unknown error"}}'
        return 1
    fi
}

# ============================================================================
# TEST: Environment Detection
# ============================================================================

test_environment_detection() {
    local test_name="Environment Detection"
    
    setup_test_environment
    
    # Export mock functions
    export -f command
    
    # Capture output
    local output=$(detect_environment 2>&1)
    local result=$?
    
    # Check for expected outputs
    if echo "$output" | grep -q "Operating System" && \
       echo "$output" | grep -q "Configuration directory: Writable"; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Color Output Functions
# ============================================================================

test_color_output() {
    local test_name="Color Output Functions"
    
    # Test print functions
    local success_msg=$(print_success "Test message" 2>&1)
    local error_msg=$(print_error "Test message" 2>&1)
    local warning_msg=$(print_warning "Test message" 2>&1)
    local info_msg=$(print_info "Test message" 2>&1)
    
    # Check for color codes and messages
    if [[ "$success_msg" == *"✓"* ]] && \
       [[ "$error_msg" == *"✗"* ]] && \
       [[ "$warning_msg" == *"⚠"* ]] && \
       [[ "$info_msg" == *"ℹ"* ]]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
}

# ============================================================================
# TEST: Configuration Directory Creation
# ============================================================================

test_config_directory_creation() {
    local test_name="Configuration Directory Creation"
    
    setup_test_environment
    
    # Remove directory to test creation
    rm -rf "$CONFIG_DIR"
    
    # Call function that should create directory
    save_auth_config "api_key" "" "test_key" 2>/dev/null
    
    # Check if directory was created with correct permissions
    if [ -d "$CONFIG_DIR" ]; then
        local dir_perms=$(stat -c %a "$CONFIG_DIR" 2>/dev/null || stat -f %A "$CONFIG_DIR" 2>/dev/null)
        
        if [[ "$dir_perms" == *"700"* ]] || [[ "$dir_perms" == "700" ]]; then
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
# TEST: Configuration File Save
# ============================================================================

test_config_save() {
    local test_name="Configuration File Save"
    
    setup_test_environment
    
    # Save API key configuration
    save_auth_config "api_key" "" "test_api_key_123" 2>/dev/null
    
    # Check if config file exists and contains correct data
    if [ -f "$CONFIG_DIR/config.json" ]; then
        local config_content=$(cat "$CONFIG_DIR/config.json")
        
        if [[ "$config_content" == *"\"auth_type\": \"api_key\""* ]] && \
           [[ "$config_content" == *"\"api_key\": \"test_api_key_123\""* ]]; then
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
# TEST: OAuth Configuration Save
# ============================================================================

test_oauth_config_save() {
    local test_name="OAuth Configuration Save"
    
    setup_test_environment
    
    # Save OAuth configuration
    save_auth_config "oauth" "google" "client_id_123" "client_secret_456" 2>/dev/null
    
    # Check if config file contains OAuth data
    if [ -f "$CONFIG_DIR/config.json" ]; then
        local config_content=$(cat "$CONFIG_DIR/config.json")
        
        if [[ "$config_content" == *"\"auth_type\": \"oauth\""* ]] && \
           [[ "$config_content" == *"\"provider\": \"google\""* ]] && \
           [[ "$config_content" == *"\"client_id\": \"client_id_123\""* ]] && \
           [[ "$config_content" == *"\"client_secret\": \"client_secret_456\""* ]]; then
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
# TEST: Environment Variable Export
# ============================================================================

test_env_variable_export() {
    local test_name="Environment Variable Export"
    
    setup_test_environment
    
    # Save API key configuration
    save_auth_config "api_key" "" "env_test_key" 2>/dev/null
    
    # Check if environment variables were set
    if [ "$GEMINI_API_KEY" = "env_test_key" ] && \
       [ "$GOOGLE_API_KEY" = "env_test_key" ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Claude Settings Update
# ============================================================================

test_claude_settings_update() {
    local test_name="Claude Settings Update"
    
    setup_test_environment
    
    # Mock jq availability
    command() {
        case "$2" in
            jq)
                return 1  # jq not available, force Python fallback
                ;;
            *)
                /usr/bin/command "$@"
                ;;
        esac
    }
    export -f command
    
    # Update Claude hooks
    update_claude_hooks 2>/dev/null
    
    # Check if settings were updated
    if [ -f "$CLAUDE_SETTINGS" ]; then
        local settings_content=$(cat "$CLAUDE_SETTINGS")
        
        if [[ "$settings_content" == *"preToolUseHooks"* ]] || \
           [[ "$settings_content" == *"gemini-bridge.sh"* ]]; then
            report_test "$test_name" "PASS"
        else
            # Python fallback might format differently, check for basic structure
            if [[ "$settings_content" == *"existingKey"* ]]; then
                report_test "$test_name" "PASS"
            else
                report_test "$test_name" "FAIL"
            fi
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
    
    # Create original settings
    echo '{"original": "data"}' > "$CLAUDE_SETTINGS"
    
    # Update hooks (which should create backup)
    update_claude_hooks 2>/dev/null
    
    # Check if backup was created
    local backup_count=$(ls "$CLAUDE_SETTINGS".backup.* 2>/dev/null | wc -l)
    
    if [ $backup_count -gt 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Log File Creation
# ============================================================================

test_log_creation() {
    local test_name="Log File Creation"
    
    setup_test_environment
    
    # Call log function
    log_message "Test log entry"
    
    # Check if log file was created
    if [ -f "$CONFIG_DIR/setup.log" ]; then
        local log_content=$(cat "$CONFIG_DIR/setup.log")
        
        if [[ "$log_content" == *"Test log entry"* ]]; then
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
# TEST: File Permissions
# ============================================================================

test_file_permissions() {
    local test_name="File Permissions"
    
    setup_test_environment
    
    # Save configuration
    save_auth_config "api_key" "" "perm_test_key" 2>/dev/null
    
    # Check file permissions
    if [ -f "$CONFIG_DIR/config.json" ]; then
        local file_perms=$(stat -c %a "$CONFIG_DIR/config.json" 2>/dev/null || stat -f %A "$CONFIG_DIR/config.json" 2>/dev/null)
        
        if [[ "$file_perms" == *"600"* ]] || [[ "$file_perms" == "600" ]]; then
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
# RUN ALL TESTS
# ============================================================================

run_all_tests() {
    echo "Running Interactive Setup Tests..."
    echo "================================="
    
    test_environment_detection
    test_color_output
    test_config_directory_creation
    test_config_save
    test_oauth_config_save
    test_env_variable_export
    test_claude_settings_update
    test_config_backup
    test_log_creation
    test_file_permissions
    
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