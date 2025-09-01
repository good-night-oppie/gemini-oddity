#!/bin/bash
# ABOUTME: Test helper functions for unit tests

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Current test name
CURRENT_TEST=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_start() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "  Testing $test_name... "
}

test_pass() {
    local message="${1:-}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} ${message}"
}

test_fail() {
    local message="${1:-}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} ${message}"
}

test_skip() {
    local message="${1:-}"
    echo -e "${YELLOW}⊘${NC} SKIPPED: ${message}"
}

test_summary() {
    echo ""
    echo "=================================="
    echo "Test Summary:"
    echo "  Total:  $TESTS_TOTAL"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String not found}"
    
    if echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  Looking for: $needle"
        echo "  In: $haystack"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File not found}"
    
    if [ -f "$file" ]; then
        return 0
    else
        echo -e "${RED}✗ $message: $file${NC}"
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command failed}"
    
    if eval "$command" > /dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}✗ $message: $command${NC}"
        return 1
    fi
}

# Setup and teardown helpers
setup_test_environment() {
    # Create temporary test directory
    export TEST_TMP_DIR=$(mktemp -d)
    export ORIGINAL_DIR=$(pwd)
}

cleanup_test_environment() {
    # Clean up temporary directory
    if [ -n "$TEST_TMP_DIR" ] && [ -d "$TEST_TMP_DIR" ]; then
        rm -rf "$TEST_TMP_DIR"
    fi
    
    # Return to original directory
    if [ -n "$ORIGINAL_DIR" ]; then
        cd "$ORIGINAL_DIR"
    fi
}

# Mock functions
create_mock_function() {
    local function_name="$1"
    local return_value="${2:-0}"
    local output="${3:-}"
    
    eval "$function_name() {
        [ -n \"$output\" ] && echo \"$output\"
        return $return_value
    }"
}