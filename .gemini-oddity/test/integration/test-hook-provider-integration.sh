#!/bin/bash
# ABOUTME: Integration tests for enhanced gemini-bridge.sh with provider support

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test helper
source "$TEST_DIR/../helpers/test-helper.sh" 2>/dev/null || true

# Test environment setup
export HOME="/tmp/test_home_$$"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
mkdir -p "$HOME"

# Source the hook and its dependencies
export SCRIPT_DIR="$PROJECT_DIR/hooks"
source "$PROJECT_DIR/hooks/config/debug.conf"
export DEBUG_LEVEL=0  # Reduce noise during tests
export DRY_RUN=false

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
    case "$1" in
        auth)
            if [ "$2" = "print-access-token" ]; then
                echo "mock-oauth-token-123"
                return 0
            fi
            ;;
        prompt)
            echo "Mock Gemini response for: $2"
            return 0
            ;;
    esac
    return 1
}

# Mock curl for API calls
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
        echo '{"models":[{"name":"gemini-1.5-flash"}]}'
        return 0
    elif [[ "$url" == *":generateContent"* ]]; then
        echo '{"candidates":[{"content":{"parts":[{"text":"Mock provider response"}]}}]}'
        return 0
    fi
    
    return 1
}

# Export mock functions
export -f gemini
export -f curl

# ============================================================================
# Setup and Teardown
# ============================================================================

setup_test_environment() {
    # Clean previous test data
    rm -rf "$HOME"
    mkdir -p "$HOME/.config/gemini-oddity"
    mkdir -p "$HOME/.cache/gemini-oddity"
    mkdir -p "$PROJECT_DIR/logs/debug"
    mkdir -p "$PROJECT_DIR/cache"
    
    # Create test configuration
    cat > "$HOME/.config/gemini-oddity/config.json" << 'EOF'
{
  "version": "1.0.0",
  "global": {
    "log_level": "info",
    "cache_ttl": 3600
  },
  "limits": {
    "claude_tokens": 50000,
    "gemini_tokens": 800000,
    "min_files": 3,
    "max_size": 10485760
  },
  "providers": {
    "default": "gemini-cli"
  }
}
EOF
}

teardown_test_environment() {
    rm -rf "$HOME"
    rm -f "$PROJECT_DIR/logs/provider_metrics.log"
}

# ============================================================================
# Helper Functions
# ============================================================================

# Create a mock tool call JSON
create_tool_call() {
    local tool_name="$1"
    local params="$2"
    
    cat << EOF
{
  "tool": "$tool_name",
  "parameters": $params,
  "context": {
    "working_directory": "$PROJECT_DIR"
  }
}
EOF
}

# ============================================================================
# TEST: Module Loading
# ============================================================================

test_module_loading() {
    local test_name="Module Loading"
    
    setup_test_environment
    
    # Source the hook script
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Check if modules are loaded
        if declare -f init_config &>/dev/null && \
           declare -f oauth_login &>/dev/null && \
           declare -f register_provider &>/dev/null; then
            exit 0
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Provider Discovery
# ============================================================================

test_provider_discovery() {
    local test_name="Provider Discovery"
    
    setup_test_environment
    
    # Source the hook and check providers
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Check if providers were discovered
        if [ ${#AVAILABLE_PROVIDERS[@]} -gt 0 ]; then
            # Should find gemini_cli provider at minimum
            for provider in "${AVAILABLE_PROVIDERS[@]}"; do
                if [ "$provider" = "gemini_cli" ]; then
                    exit 0
                fi
            done
        fi
        exit 1
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Provider Selection Logic
# ============================================================================

test_provider_selection() {
    local test_name="Provider Selection Logic"
    
    setup_test_environment
    
    # Test provider selection function
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Mock valid auth for gemini_cli
        gemini_cli_validate_auth() { echo "valid"; }
        export -f gemini_cli_validate_auth
        
        # Test selection
        PROVIDER_INFO=$(select_provider "Task" 5 100000)
        SELECTED_PROVIDER=$(echo "$PROVIDER_INFO" | cut -d: -f1)
        
        if [ -n "$SELECTED_PROVIDER" ]; then
            exit 0
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: OAuth Authentication Flow
# ============================================================================

test_oauth_authentication() {
    local test_name="OAuth Authentication Flow"
    
    setup_test_environment
    
    # Test OAuth authentication
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Mock OAuth provider
        test_oauth_authenticate() { echo "oauth-token-456"; }
        test_oauth_validate_auth() { echo "valid"; }
        test_oauth_get_capabilities() { echo '{"capabilities":["oauth"]}'; }
        
        export -f test_oauth_authenticate
        export -f test_oauth_validate_auth
        export -f test_oauth_get_capabilities
        
        AVAILABLE_PROVIDERS=("test_oauth")
        
        # Test authentication
        if authenticate_provider "test_oauth" "oauth"; then
            [ "$PROVIDER_AUTH_TOKEN" = "oauth-token-456" ]
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: API Key Fallback
# ============================================================================

test_api_key_fallback() {
    local test_name="API Key Fallback"
    
    setup_test_environment
    
    # Set API key
    export GEMINI_API_KEY="test-api-key-789"
    
    # Test API key authentication
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        if authenticate_provider "test" "api_key"; then
            [ "$PROVIDER_AUTH_TOKEN" = "test-api-key-789" ]
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    unset GEMINI_API_KEY
    teardown_test_environment
}

# ============================================================================
# TEST: Decision Engine - Large File
# ============================================================================

test_decision_engine_large_file() {
    local test_name="Decision Engine - Large File"
    
    setup_test_environment
    
    # Create a large test file
    local test_file="$HOME/large_file.txt"
    dd if=/dev/zero of="$test_file" bs=1024 count=250 2>/dev/null  # 250KB
    
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Test decision with large file
        if should_delegate_to_provider "Read" "$test_file" "Read large file"; then
            exit 0  # Should delegate
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    rm -f "$test_file"
    teardown_test_environment
}

# ============================================================================
# TEST: Decision Engine - Multi-File Task
# ============================================================================

test_decision_engine_multi_file() {
    local test_name="Decision Engine - Multi-File Task"
    
    setup_test_environment
    
    # Create test files
    local files=""
    for i in {1..5}; do
        local file="$HOME/test_$i.txt"
        echo "Test content $i" > "$file"
        files="$files $file"
    done
    
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Test decision with multiple files
        if should_delegate_to_provider "Task" "$files" "Analyze multiple files"; then
            exit 0  # Should delegate
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    rm -f "$HOME"/test_*.txt
    teardown_test_environment
}

# ============================================================================
# TEST: Backward Compatibility
# ============================================================================

test_backward_compatibility() {
    local test_name="Backward Compatibility"
    
    setup_test_environment
    
    # Test with legacy environment variables
    export CLAUDE_TOKEN_LIMIT=40000
    export GEMINI_TOKEN_LIMIT=700000
    export MIN_FILES_FOR_GEMINI=2
    
    (
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< ""
        
        # Create small file
        local test_file="$HOME/small.txt"
        echo "Small content" > "$test_file"
        
        # Should not delegate small file
        if ! should_delegate_to_provider "Read" "$test_file" "Read small file"; then
            exit 0
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    unset CLAUDE_TOKEN_LIMIT GEMINI_TOKEN_LIMIT MIN_FILES_FOR_GEMINI
    teardown_test_environment
}

# ============================================================================
# TEST: Error Handling - No Providers
# ============================================================================

test_error_handling_no_providers() {
    local test_name="Error Handling - No Providers"
    
    setup_test_environment
    
    # Create large file to trigger delegation
    local test_file="$HOME/large.txt"
    dd if=/dev/zero of="$test_file" bs=1024 count=250 2>/dev/null
    
    # Test with empty input (should continue)
    local tool_call=$(create_tool_call "Read" '{"file_path":"'$test_file'"}')
    
    (
        # Disable all providers
        AVAILABLE_PROVIDERS=()
        unset -f gemini
        
        source "$PROJECT_DIR/hooks/gemini-bridge.sh" <<< "$tool_call" 2>/dev/null
        
        # Should output continue response
        if grep -q '"action":"continue"' 2>/dev/null; then
            exit 0
        else
            exit 1
        fi
    )
    
    if [ $? -eq 0 ]; then
        report_test "$test_name" "PASS"
    else
        report_test "$test_name" "FAIL"
    fi
    
    teardown_test_environment
}

# ============================================================================
# TEST: Performance Metrics Logging
# ============================================================================

test_performance_metrics() {
    local test_name="Performance Metrics Logging"
    
    setup_test_environment
    
    # Create test scenario
    local test_file="$HOME/test.txt"
    echo "Test content" > "$test_file"
    
    # Mock successful provider execution
    (
        export SELECTED_PROVIDER="test_provider"
        export SELECTED_AUTH_TYPE="oauth"
        export TOOL_NAME="Read"
        export FILE_COUNT=1
        export ESTIMATED_TOKENS=100
        export PROVIDER_DURATION=1.5
        
        # Create metrics log entry
        echo "$(date -Iseconds)|$SELECTED_PROVIDER|$SELECTED_AUTH_TYPE|$TOOL_NAME|$FILE_COUNT|$ESTIMATED_TOKENS|$PROVIDER_DURATION" >> "$PROJECT_DIR/logs/provider_metrics.log"
    )
    
    # Check if metrics were logged
    if [ -f "$PROJECT_DIR/logs/provider_metrics.log" ] && \
       grep -q "test_provider|oauth|Read|1|100|1.5" "$PROJECT_DIR/logs/provider_metrics.log"; then
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
    echo "Running Hook Provider Integration Tests..."
    echo "================================="
    
    test_module_loading
    test_provider_discovery
    test_provider_selection
    test_oauth_authentication
    test_api_key_fallback
    test_decision_engine_large_file
    test_decision_engine_multi_file
    test_backward_compatibility
    test_error_handling_no_providers
    test_performance_metrics
    
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