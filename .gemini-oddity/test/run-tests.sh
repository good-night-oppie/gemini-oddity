#!/bin/bash
# ABOUTME: Main test runner for gemini-oddity

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/helpers/test-framework.sh"

# Default test directories
UNIT_TEST_DIR="$SCRIPT_DIR/unit"
INTEGRATION_TEST_DIR="$SCRIPT_DIR/integration"

# Parse command line options
TEST_TYPE="all"
VERBOSE=0
TEST_PATTERN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            TEST_TYPE="unit"
            shift
            ;;
        --integration)
            TEST_TYPE="integration"
            shift
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --pattern|-p)
            TEST_PATTERN="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --unit              Run only unit tests"
            echo "  --integration       Run only integration tests"
            echo "  --verbose, -v       Show verbose test output"
            echo "  --pattern, -p       Run only tests matching pattern"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

export VERBOSE

# Find test files
find_test_files() {
    local dir="$1"
    local pattern="$2"
    
    if [ -n "$pattern" ]; then
        find "$dir" -name "*${pattern}*_test.sh" -type f 2>/dev/null | sort
    else
        find "$dir" -name "*_test.sh" -type f 2>/dev/null | sort
    fi
}

# Collect test files
TEST_FILES=()

case "$TEST_TYPE" in
    unit)
        echo "Running unit tests..."
        mapfile -t TEST_FILES < <(find_test_files "$UNIT_TEST_DIR" "$TEST_PATTERN")
        ;;
    integration)
        echo "Running integration tests..."
        mapfile -t TEST_FILES < <(find_test_files "$INTEGRATION_TEST_DIR" "$TEST_PATTERN")
        ;;
    all)
        echo "Running all tests..."
        mapfile -t UNIT_FILES < <(find_test_files "$UNIT_TEST_DIR" "$TEST_PATTERN")
        mapfile -t INT_FILES < <(find_test_files "$INTEGRATION_TEST_DIR" "$TEST_PATTERN")
        TEST_FILES=("${UNIT_FILES[@]}" "${INT_FILES[@]}")
        ;;
esac

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo "No test files found matching criteria"
    exit 0
fi

echo "Found ${#TEST_FILES[@]} test file(s)"
echo

# Run each test file
for test_file in "${TEST_FILES[@]}"; do
    echo "Running: $test_file"
    bash "$test_file"
done