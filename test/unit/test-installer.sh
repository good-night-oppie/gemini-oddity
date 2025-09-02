#!/bin/bash
# ABOUTME: Comprehensive tests for enhanced installer components

# Test suite for Gemini Oddity Enhanced Installer

set -euo pipefail

# Test framework
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$TEST_DIR/helpers/test-framework.sh"

# Setup test environment
setup_test_env() {
    export TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    export GEMINI_ODDITY_NOTIFY="quiet"
    
    # Create mock directories
    mkdir -p "$HOME/.claude"
    mkdir -p "$HOME/.gemini"
    
    # Mock Claude settings
    echo '{}' > "$HOME/.claude/settings.json"
    
    # Mock OAuth credentials (valid)
    local future_time=$(($(date +%s) + 3600))
    cat > "$HOME/.gemini/oauth_creds.json" <<EOF
{
    "access_token": "mock_token_12345",
    "refresh_token": "mock_refresh_67890",
    "exp": $future_time,
    "scope": "https://www.googleapis.com/auth/generativelanguage.tuning"
}
EOF
}

teardown_test_env() {
    rm -rf "$TEST_HOME"
}

# Test: Universal router initialization
test_universal_router_init() {
    start_test "Universal router initialization"
    
    setup_test_env
    
    # Source the router
    source "$PROJECT_ROOT/hooks/universal-router.sh" 2>/dev/null || true
    
    # Initialize registry
    initialize_registry
    
    # Check registry was created
    assert_file_exists "$HOME/.claude/oddity-registry.json" \
        "Registry file should be created"
    
    # Verify registry structure
    local version=$(jq -r '.version' "$HOME/.claude/oddity-registry.json")
    assert_equals "$version" "2.0.0" "Registry version should be 2.0.0"
    
    local projects=$(jq -r '.projects | length' "$HOME/.claude/oddity-registry.json")
    assert_equals "$projects" "0" "Registry should start with no projects"
    
    teardown_test_env
    end_test
}

# Test: Project registration
test_project_registration() {
    start_test "Project registration"
    
    setup_test_env
    
    # Create test project directory
    local test_project="$HOME/test-project"
    mkdir -p "$test_project/.gemini-oddity"
    
    # Source installer functions
    source "$PROJECT_ROOT/scripts/install-bridge.sh" 2>/dev/null || true
    
    # Register project
    register_project "$test_project" "Read|Task"
    
    # Verify registration
    assert_file_exists "$HOME/.claude/oddity-registry.json" \
        "Registry should exist after registration"
    
    local registered=$(jq --arg dir "$test_project" '.projects[$dir] // null' \
        "$HOME/.claude/oddity-registry.json")
    assert_not_equals "$registered" "null" "Project should be registered"
    
    local tools=$(echo "$registered" | jq -r '.config.tools')
    assert_equals "$tools" "Read|Task" "Tools should match registration"
    
    local enabled=$(echo "$registered" | jq -r '.config.enabled')
    assert_equals "$enabled" "true" "Project should be enabled by default"
    
    teardown_test_env
    end_test
}

# Test: OAuth status checking
test_oauth_status_check() {
    start_test "OAuth status checking"
    
    setup_test_env
    
    # Source OAuth manager
    source "$PROJECT_ROOT/hooks/lib/oauth-manager.sh" 2>/dev/null || true
    
    # Test valid token
    local status=$(check_oauth_status)
    assert_equals "$status" "valid" "Should detect valid token"
    
    # Test expired token
    local past_time=$(($(date +%s) - 3600))
    cat > "$HOME/.gemini/oauth_creds.json" <<EOF
{
    "exp": $past_time
}
EOF
    
    status=$(check_oauth_status)
    assert_equals "$status" "expired" "Should detect expired token"
    
    # Test no token
    rm -f "$HOME/.gemini/oauth_creds.json"
    status=$(check_oauth_status)
    assert_equals "$status" "not_authenticated" "Should detect missing token"
    
    teardown_test_env
    end_test
}

# Test: Notification system
test_notification_system() {
    start_test "Notification system"
    
    setup_test_env
    
    # Source notification functions
    source "$PROJECT_ROOT/hooks/universal-router.sh" 2>/dev/null || true
    
    # Test quiet mode
    export GEMINI_ODDITY_NOTIFY="quiet"
    local output=$(notify_user "DELEGATE" "Test message" 2>&1)
    assert_equals "$output" "" "Quiet mode should produce no output"
    
    # Test subtle mode
    export GEMINI_ODDITY_NOTIFY="subtle"
    output=$(notify_user "DELEGATE" "Test message" 2>&1)
    assert_contains "$output" "🌉" "Subtle mode should show bridge icon"
    
    # Test verbose mode
    export GEMINI_ODDITY_NOTIFY="verbose"
    output=$(notify_user "SUCCESS" "Test success" 2>&1)
    assert_contains "$output" "Bridge" "Verbose mode should show full message"
    assert_contains "$output" "Test success" "Message should be included"
    
    # Verify logging
    assert_file_exists "$HOME/.claude/oddity-status.log" \
        "Status log should be created"
    
    local log_content=$(cat "$HOME/.claude/oddity-status.log")
    assert_contains "$log_content" "Test message" "Messages should be logged"
    
    teardown_test_env
    end_test
}

# Test: Working directory extraction
test_working_directory_extraction() {
    start_test "Working directory extraction"
    
    setup_test_env
    
    # Source router functions
    source "$PROJECT_ROOT/hooks/universal-router.sh" 2>/dev/null || true
    
    # Test with file_path
    local tool_call='{"tool": "Read", "file_path": "/home/user/project/file.txt"}'
    local working_dir=$(echo "$tool_call" | extract_working_directory -)
    assert_contains "$working_dir" "project" "Should extract directory from file path"
    
    # Test with path
    tool_call='{"tool": "Glob", "path": "/home/user/another-project"}'
    working_dir=$(echo "$tool_call" | extract_working_directory -)
    assert_contains "$working_dir" "another-project" "Should use path directly"
    
    # Test fallback to PWD
    cd "$HOME"
    tool_call='{"tool": "Task"}'
    working_dir=$(echo "$tool_call" | extract_working_directory -)
    assert_equals "$working_dir" "$HOME" "Should fall back to current directory"
    
    teardown_test_env
    end_test
}

# Test: Project root finding
test_project_root_finding() {
    start_test "Project root finding"
    
    setup_test_env
    
    # Create nested project structure
    mkdir -p "$HOME/workspace/project/.gemini-oddity"
    mkdir -p "$HOME/workspace/project/src/components"
    
    # Source router functions
    source "$PROJECT_ROOT/hooks/universal-router.sh" 2>/dev/null || true
    
    # Register project
    initialize_registry
    register_project "$HOME/workspace/project" "Read|Task" 2>/dev/null || true
    
    # Test finding from subdirectory
    local project_root=$(find_project_root "$HOME/workspace/project/src/components")
    assert_equals "$project_root" "$HOME/workspace/project" \
        "Should find project root from subdirectory"
    
    # Test no project found
    project_root=$(find_project_root "$HOME/other-dir" 2>/dev/null || echo "")
    assert_equals "$project_root" "" "Should return empty for non-project directory"
    
    teardown_test_env
    end_test
}

# Test: Token refresh mechanism
test_token_refresh() {
    start_test "Token refresh mechanism"
    
    setup_test_env
    
    # Mock gemini command
    gemini() {
        if [[ "$1" == "-p" ]] && [[ "$2" == "test" ]]; then
            # Update token expiry to simulate refresh
            local new_expiry=$(($(date +%s) + 3600))
            jq --arg exp "$new_expiry" '.exp = ($exp | tonumber)' \
                "$HOME/.gemini/oauth_creds.json" > "$HOME/.gemini/oauth_creds.json.tmp"
            mv "$HOME/.gemini/oauth_creds.json.tmp" "$HOME/.gemini/oauth_creds.json"
            return 0
        fi
        return 1
    }
    export -f gemini
    
    # Source OAuth manager
    source "$PROJECT_ROOT/hooks/lib/oauth-manager.sh" 2>/dev/null || true
    
    # Set token to expire soon
    local near_expiry=$(($(date +%s) + 100))
    cat > "$HOME/.gemini/oauth_creds.json" <<EOF
{
    "exp": $near_expiry
}
EOF
    
    # Test auto-refresh
    ensure_authenticated
    local result=$?
    assert_equals "$result" "0" "Should successfully refresh token"
    
    # Verify token was refreshed
    local new_exp=$(jq -r '.exp' "$HOME/.gemini/oauth_creds.json")
    assert_greater_than "$new_exp" "$near_expiry" "Token expiry should be extended"
    
    teardown_test_env
    end_test
}

# Test: CLI commands
test_cli_commands() {
    start_test "CLI commands"
    
    setup_test_env
    
    # Make CLI executable
    chmod +x "$PROJECT_ROOT/gemini-oddity"
    
    # Test help command
    local output=$("$PROJECT_ROOT/gemini-oddity" help 2>&1)
    assert_contains "$output" "Gemini Oddity CLI" "Help should show title"
    assert_contains "$output" "install" "Help should list install command"
    
    # Test version command
    output=$("$PROJECT_ROOT/gemini-oddity" version 2>&1)
    assert_contains "$output" "2.0.0" "Version should show CLI version"
    
    # Test status command (with minimal setup)
    output=$("$PROJECT_ROOT/gemini-oddity" status 2>&1 || true)
    assert_contains "$output" "Gemini Oddity Status" "Status should show header"
    
    teardown_test_env
    end_test
}

# Test: Multi-project isolation
test_multi_project_isolation() {
    start_test "Multi-project isolation"
    
    setup_test_env
    
    # Create multiple projects
    mkdir -p "$HOME/project-a/.gemini-oddity"
    mkdir -p "$HOME/project-b/.gemini-oddity"
    
    # Source installer functions
    source "$PROJECT_ROOT/scripts/install-bridge.sh" 2>/dev/null || true
    
    # Register both projects with different tools
    register_project "$HOME/project-a" "Read|Grep"
    register_project "$HOME/project-b" "Task"
    
    # Verify both are registered
    local registry=$(cat "$HOME/.claude/oddity-registry.json")
    assert_contains "$registry" "project-a" "Project A should be registered"
    assert_contains "$registry" "project-b" "Project B should be registered"
    
    # Verify different configurations
    local tools_a=$(jq -r '.projects["/home/test-tmp/project-a"].config.tools' \
        "$HOME/.claude/oddity-registry.json" 2>/dev/null || echo "")
    local tools_b=$(jq -r '.projects["/home/test-tmp/project-b"].config.tools' \
        "$HOME/.claude/oddity-registry.json" 2>/dev/null || echo "")
    
    assert_not_equals "$tools_a" "$tools_b" "Projects should have different tool configs"
    
    teardown_test_env
    end_test
}

# Run all tests
run_test_suite() {
    echo "================================"
    echo "Enhanced Installer Test Suite"
    echo "================================"
    echo ""
    
    test_universal_router_init
    test_project_registration
    test_oauth_status_check
    test_notification_system
    test_working_directory_extraction
    test_project_root_finding
    test_token_refresh
    test_cli_commands
    test_multi_project_isolation
    
    echo ""
    echo "================================"
    echo "Test Summary"
    echo "================================"
    print_test_summary
}

# Export functions for testing
export -f setup_test_env teardown_test_env register_project

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite
fi