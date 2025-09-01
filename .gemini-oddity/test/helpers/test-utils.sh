#!/bin/bash
# ABOUTME: Extended test utilities for comprehensive test suite

# Source basic test helper
source "$(dirname "$0")/test-helper.sh"

# Additional assertion functions
assert_json_valid() {
    local json="$1"
    local message="${2:-Invalid JSON}"
    
    if echo "$json" | jq empty 2>/dev/null; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  JSON: $json"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value is empty}"
    
    if [ -n "$value" ]; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        return 1
    fi
}

assert_permissions() {
    local file="$1"
    local expected_perms="$2"
    local message="${3:-Incorrect permissions}"
    
    local actual_perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        actual_perms=$(stat -f "%A" "$file" 2>/dev/null)
    else
        actual_perms=$(stat -c "%a" "$file" 2>/dev/null)
    fi
    
    if [ "$actual_perms" = "$expected_perms" ]; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  File: $file"
        echo "  Expected: $expected_perms"
        echo "  Actual: $actual_perms"
        return 1
    fi
}

assert_greater_than() {
    local value1="$1"
    local value2="$2"
    local message="${3:-Value not greater}"
    
    if [ "$value1" -gt "$value2" ] 2>/dev/null; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  $value1 is not greater than $value2"
        return 1
    fi
}

assert_less_than() {
    local value1="$1"
    local value2="$2"
    local message="${3:-Value not less}"
    
    if [ "$value1" -lt "$value2" ] 2>/dev/null; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  $value1 is not less than $value2"
        return 1
    fi
}

# Mock command creation with tracking
MOCK_CALLS=()

mock_command() {
    local command_name="$1"
    local mock_behavior="$2"
    
    # Track mock calls
    eval "${command_name}_original=$(which $command_name 2>/dev/null || echo '')"
    
    # Create mock function
    eval "$command_name() {
        MOCK_CALLS+=('$command_name \$*')
        $mock_behavior
    }"
    
    export -f $command_name
}

reset_mocks() {
    MOCK_CALLS=()
}

verify_mock_called() {
    local command_pattern="$1"
    
    for call in "${MOCK_CALLS[@]}"; do
        if echo "$call" | grep -q "$command_pattern"; then
            return 0
        fi
    done
    
    echo -e "${RED}✗ Mock not called: $command_pattern${NC}"
    echo "  Actual calls: ${MOCK_CALLS[*]}"
    return 1
}

# Performance testing helpers
measure_time() {
    local command="$1"
    local max_ms="${2:-1000}"
    local message="${3:-Performance test}"
    
    local start=$(date +%s%N)
    eval "$command" > /dev/null 2>&1
    local end=$(date +%s%N)
    
    local duration_ns=$((end - start))
    local duration_ms=$((duration_ns / 1000000))
    
    if [ "$duration_ms" -le "$max_ms" ]; then
        echo -e "${GREEN}✓ $message: ${duration_ms}ms${NC}"
        return 0
    else
        echo -e "${RED}✗ $message: ${duration_ms}ms (max: ${max_ms}ms)${NC}"
        return 1
    fi
}

# Test data generators
generate_test_token() {
    local token_type="${1:-access}"
    local expiry="${2:-3600}"
    
    local token="test_${token_type}_token_$(date +%s)"
    local expires_at=$(($(date +%s) + expiry))
    
    echo "{
        \"token\": \"$token\",
        \"type\": \"$token_type\",
        \"expires_at\": $expires_at,
        \"scope\": \"test.scope\"
    }"
}

generate_oauth_config() {
    cat <<EOF
{
    "auth_type": "oauth",
    "provider": "test",
    "oauth": {
        "client_id": "test_client_id",
        "client_secret": "test_client_secret",
        "redirect_uri": "http://localhost:8080/callback",
        "scope": "test.scope",
        "token_endpoint": "https://test.oauth.com/token",
        "auth_endpoint": "https://test.oauth.com/auth"
    },
    "encryption": {
        "enabled": true,
        "algorithm": "aes-256-cbc"
    }
}
EOF
}

# Coverage tracking
COVERAGE_FUNCTIONS=()
COVERAGE_LINES=()

track_coverage() {
    local file="$1"
    local function="$2"
    local line="${3:-}"
    
    COVERAGE_FUNCTIONS+=("$file:$function")
    [ -n "$line" ] && COVERAGE_LINES+=("$file:$line")
}

generate_coverage_report() {
    local total_functions=${#COVERAGE_FUNCTIONS[@]}
    local total_lines=${#COVERAGE_LINES[@]}
    
    echo "Coverage Report:"
    echo "  Functions covered: $total_functions"
    echo "  Lines covered: $total_lines"
    
    # Calculate percentage if baseline is known
    local baseline_functions="${1:-100}"
    local baseline_lines="${2:-1000}"
    
    local func_coverage=$((total_functions * 100 / baseline_functions))
    local line_coverage=$((total_lines * 100 / baseline_lines))
    
    echo "  Function coverage: ${func_coverage}%"
    echo "  Line coverage: ${line_coverage}%"
}

# Security testing helpers
check_for_secrets() {
    local file="$1"
    local patterns=(
        "password['\"]?[[:space:]]*[:=]"
        "secret['\"]?[[:space:]]*[:=]"
        "token['\"]?[[:space:]]*[:=]"
        "api[_-]?key['\"]?[[:space:]]*[:=]"
        "AIza[0-9A-Za-z_-]{35}"
    )
    
    for pattern in "${patterns[@]}"; do
        if grep -Ei "$pattern" "$file" > /dev/null 2>&1; then
            echo -e "${RED}✗ Potential secret found in $file${NC}"
            return 1
        fi
    done
    
    return 0
}

# Concurrent testing helpers
run_concurrent_tests() {
    local test_function="$1"
    local concurrency="${2:-5}"
    
    local pids=()
    
    for i in $(seq 1 $concurrency); do
        $test_function $i &
        pids+=($!)
    done
    
    local failed=0
    for pid in "${pids[@]}"; do
        wait $pid || ((failed++))
    done
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✓ All $concurrency concurrent tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $failed concurrent tests failed${NC}"
        return 1
    fi
}

# Snapshot testing
save_snapshot() {
    local name="$1"
    local content="$2"
    local snapshot_dir="${TEST_TMP_DIR:-/tmp}/snapshots"
    
    mkdir -p "$snapshot_dir"
    echo "$content" > "$snapshot_dir/$name.snapshot"
}

compare_snapshot() {
    local name="$1"
    local content="$2"
    local snapshot_dir="${TEST_TMP_DIR:-/tmp}/snapshots"
    local snapshot_file="$snapshot_dir/$name.snapshot"
    
    if [ ! -f "$snapshot_file" ]; then
        echo -e "${YELLOW}⊘ No snapshot found for $name, creating...${NC}"
        save_snapshot "$name" "$content"
        return 0
    fi
    
    local expected=$(cat "$snapshot_file")
    if [ "$expected" = "$content" ]; then
        return 0
    else
        echo -e "${RED}✗ Snapshot mismatch for $name${NC}"
        diff -u "$snapshot_file" - <<< "$content"
        return 1
    fi
}

# Export all functions
export -f assert_json_valid assert_not_empty assert_permissions
export -f assert_greater_than assert_less_than
export -f mock_command reset_mocks verify_mock_called
export -f measure_time generate_test_token generate_oauth_config
export -f track_coverage generate_coverage_report
export -f check_for_secrets run_concurrent_tests
export -f save_snapshot compare_snapshot