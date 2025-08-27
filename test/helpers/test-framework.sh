#!/bin/bash
# ABOUTME: Test framework for claude-gemini-bridge shell scripts

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test statistics
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""
CURRENT_SUITE=""

# Test output control
VERBOSE=${VERBOSE:-0}

# Setup and teardown functions
SETUP_FUNCTION=""
TEARDOWN_FUNCTION=""

# Test assertion functions

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [ "$expected" = "$actual" ]; then
        pass "$message"
    else
        fail "$message: expected '$expected' but got '$actual'"
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    if [ "$unexpected" != "$actual" ]; then
        pass "$message"
    else
        fail "$message: expected value to not be '$unexpected'"
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    if eval "$condition"; then
        pass "$message"
    else
        fail "$message: condition '$condition' is false"
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"
    
    if ! eval "$condition"; then
        pass "$message"
    else
        fail "$message: condition '$condition' is true"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$message"
    else
        fail "$message: '$haystack' does not contain '$needle'"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$message"
    else
        fail "$message: '$haystack' contains '$needle'"
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [ -f "$file" ]; then
        pass "$message"
    else
        fail "$message: file '$file' does not exist"
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"
    
    if [ ! -f "$file" ]; then
        pass "$message"
    else
        fail "$message: file '$file' exists"
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    if [ -d "$dir" ]; then
        pass "$message"
    else
        fail "$message: directory '$dir' does not exist"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"
    
    if [ "$expected" -eq "$actual" ]; then
        pass "$message"
    else
        fail "$message: expected exit code $expected but got $actual"
    fi
}

# Test execution functions

describe() {
    local suite_name="$1"
    CURRENT_SUITE="$suite_name"
    echo -e "\n${BLUE}Test Suite: $suite_name${NC}"
}

it() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    ((TESTS_RUN++))
    
    [ "$VERBOSE" -eq 1 ] && echo -e "\n  ${YELLOW}Running: $test_name${NC}"
    
    # Run setup if defined
    if [ -n "$SETUP_FUNCTION" ] && declare -f "$SETUP_FUNCTION" > /dev/null; then
        "$SETUP_FUNCTION"
    fi
    
    # Shift to get the test function
    shift
    
    # Execute the test
    if "$@"; then
        # Test passed (no explicit fail was called)
        :
    fi
    
    # Run teardown if defined
    if [ -n "$TEARDOWN_FUNCTION" ] && declare -f "$TEARDOWN_FUNCTION" > /dev/null; then
        "$TEARDOWN_FUNCTION"
    fi
}

setup() {
    SETUP_FUNCTION="$1"
}

teardown() {
    TEARDOWN_FUNCTION="$1"
}

pass() {
    local message="$1"
    ((TESTS_PASSED++))
    [ "$VERBOSE" -eq 1 ] && echo -e "    ${GREEN}✓ $message${NC}"
}

fail() {
    local message="$1"
    ((TESTS_FAILED++))
    echo -e "    ${RED}✗ $CURRENT_TEST${NC}"
    echo -e "      ${RED}$message${NC}"
    return 1
}

skip() {
    local message="${1:-Test skipped}"
    echo -e "    ${YELLOW}⊘ $CURRENT_TEST - $message${NC}"
    ((TESTS_RUN--))  # Don't count skipped tests
}

# Mock and stub functions

mock_function() {
    local function_name="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"
    
    # Save original function if it exists
    if declare -f "$function_name" > /dev/null; then
        eval "original_${function_name}() { $(declare -f "$function_name" | tail -n +2) }"
    fi
    
    # Create mock function
    eval "$function_name() { echo '$mock_output'; return $mock_exit_code; }"
}

restore_function() {
    local function_name="$1"
    
    # Restore original function if it was saved
    if declare -f "original_${function_name}" > /dev/null; then
        eval "$function_name() { $(declare -f "original_${function_name}" | tail -n +2) }"
        unset -f "original_${function_name}"
    else
        unset -f "$function_name"
    fi
}

stub_command() {
    local command="$1"
    local stub_script="$2"
    
    # Create a temporary directory for stubs if it doesn't exist
    STUB_DIR="${STUB_DIR:-/tmp/test-stubs-$$}"
    mkdir -p "$STUB_DIR"
    
    # Create stub script
    cat > "$STUB_DIR/$command" << EOF
#!/bin/bash
$stub_script
EOF
    chmod +x "$STUB_DIR/$command"
    
    # Add stub directory to PATH
    export PATH="$STUB_DIR:$PATH"
}

cleanup_stubs() {
    if [ -n "$STUB_DIR" ] && [ -d "$STUB_DIR" ]; then
        rm -rf "$STUB_DIR"
    fi
}

# Test runner

run_tests() {
    echo -e "${BLUE}Running tests...${NC}"
    
    # Execute all test functions
    for test_file in "$@"; do
        if [ -f "$test_file" ]; then
            source "$test_file"
        fi
    done
    
    # Print summary
    echo -e "\n${BLUE}Test Summary:${NC}"
    echo -e "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    # Cleanup
    cleanup_stubs
    
    # Exit with appropriate code
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        return 1
    fi
}

# JSON test helpers

assert_valid_json() {
    local json="$1"
    local message="${2:-Should be valid JSON}"
    
    if echo "$json" | python3 -m json.tool > /dev/null 2>&1 || \
       echo "$json" | python -m json.tool > /dev/null 2>&1; then
        pass "$message"
    else
        fail "$message: invalid JSON"
    fi
}

assert_json_field_equals() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local message="${4:-JSON field should equal expected value}"
    
    # Try to extract field value using grep and sed (basic JSON parsing)
    local actual=$(echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*: *"\([^"]*\)".*/\1/')
    
    if [ "$actual" = "$expected" ]; then
        pass "$message"
    else
        fail "$message: field '$field' expected '$expected' but got '$actual'"
    fi
}

# Temporary file helpers

create_temp_dir() {
    local dir=$(mktemp -d)
    echo "$dir"
}

cleanup_temp_dir() {
    local dir="$1"
    if [ -d "$dir" ] && [[ "$dir" == /tmp/* ]]; then
        rm -rf "$dir"
    fi
}