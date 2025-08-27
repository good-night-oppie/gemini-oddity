#!/bin/bash
# ABOUTME: Main test orchestrator for comprehensive test suite

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test utilities
source "$SCRIPT_DIR/helpers/test-utils.sh"

# Test configuration
COVERAGE_TARGET_UNIT=85
COVERAGE_TARGET_INTEGRATION=75
COVERAGE_TARGET_E2E=60

# Color output
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     Claude-Gemini Bridge Comprehensive Test Suite     ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Parse command line arguments
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_E2E=true
RUN_SECURITY=true
RUN_PERFORMANCE=true
COVERAGE_REPORT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            RUN_INTEGRATION=false
            RUN_E2E=false
            RUN_SECURITY=false
            RUN_PERFORMANCE=false
            ;;
        --integration-only)
            RUN_UNIT=false
            RUN_E2E=false
            RUN_SECURITY=false
            RUN_PERFORMANCE=false
            ;;
        --e2e-only)
            RUN_UNIT=false
            RUN_INTEGRATION=false
            RUN_SECURITY=false
            RUN_PERFORMANCE=false
            ;;
        --coverage)
            COVERAGE_REPORT=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--unit-only|--integration-only|--e2e-only] [--coverage] [--verbose]"
            exit 1
            ;;
    esac
    shift
done

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SUITE_RESULTS=()

# Function to run a test suite
run_test_suite() {
    local suite_name="$1"
    local suite_dir="$2"
    local coverage_target="${3:-0}"
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Running $suite_name Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    local suite_passed=0
    local suite_failed=0
    local suite_total=0
    
    # Find and run all test files in suite directory
    for test_file in "$SCRIPT_DIR/$suite_dir"/*.sh; do
        if [ -f "$test_file" ]; then
            local test_name=$(basename "$test_file" .sh)
            
            # Skip helper files
            if [[ "$test_name" == *"helper"* ]] || [[ "$test_name" == *"mock"* ]]; then
                continue
            fi
            
            echo ""
            echo "📝 Running: $test_name"
            echo "────────────────────────────────────────"
            
            suite_total=$((suite_total + 1))
            
            # Run test with timeout
            if timeout 30 bash "$test_file"; then
                echo -e "${GREEN}✓ $test_name passed${NC}"
                suite_passed=$((suite_passed + 1))
            else
                echo -e "${RED}✗ $test_name failed${NC}"
                suite_failed=$((suite_failed + 1))
            fi
        fi
    done
    
    # Suite summary
    echo ""
    echo "────────────────────────────────────────"
    echo "$suite_name Suite Summary:"
    echo "  Total: $suite_total"
    echo -e "  Passed: ${GREEN}$suite_passed${NC}"
    echo -e "  Failed: ${RED}$suite_failed${NC}"
    
    # Check coverage target
    if [ $coverage_target -gt 0 ] && [ $suite_total -gt 0 ]; then
        local coverage=$((suite_passed * 100 / suite_total))
        if [ $coverage -ge $coverage_target ]; then
            echo -e "  Coverage: ${GREEN}${coverage}% (target: ${coverage_target}%)${NC}"
        else
            echo -e "  Coverage: ${RED}${coverage}% (target: ${coverage_target}%)${NC}"
        fi
    fi
    
    # Update overall results
    if [ $suite_failed -eq 0 ]; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
        SUITE_RESULTS+=("${GREEN}✓ $suite_name: All tests passed${NC}")
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
        SUITE_RESULTS+=("${RED}✗ $suite_name: $suite_failed tests failed${NC}")
    fi
}

# Create test environment
echo "🔧 Setting up test environment..."
setup_test_environment

# Create necessary directories
mkdir -p "$TEST_TMP_DIR/config"
mkdir -p "$TEST_TMP_DIR/tokens"
mkdir -p "$TEST_TMP_DIR/cache"
mkdir -p "$TEST_TMP_DIR/logs"

# Set test environment variables
export CLAUDE_GEMINI_BRIDGE_DIR="$TEST_TMP_DIR"
export OAUTH_DEBUG=true
export DEBUG_LEVEL=0  # Quiet for tests
export DRY_RUN=true  # No real API calls

# Run Unit Tests
if [ "$RUN_UNIT" = true ]; then
    run_test_suite "Unit" "unit" $COVERAGE_TARGET_UNIT
fi

# Run Integration Tests
if [ "$RUN_INTEGRATION" = true ]; then
    run_test_suite "Integration" "integration" $COVERAGE_TARGET_INTEGRATION
fi

# Run E2E Tests
if [ "$RUN_E2E" = true ]; then
    run_test_suite "End-to-End" "e2e" $COVERAGE_TARGET_E2E
fi

# Run Security Tests
if [ "$RUN_SECURITY" = true ]; then
    run_test_suite "Security" "security" 0
fi

# Run Performance Tests
if [ "$RUN_PERFORMANCE" = true ]; then
    run_test_suite "Performance" "performance" 0
fi

# Generate coverage report if requested
if [ "$COVERAGE_REPORT" = true ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Coverage Report${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Generate HTML coverage report
    "$SCRIPT_DIR/reports/generate-coverage-report.sh" || true
fi

# Cleanup
cleanup_test_environment

# Final Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                   FINAL SUMMARY                       ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Test Suites Run: $TOTAL_SUITES"
echo -e "Suites Passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Suites Failed: ${RED}$FAILED_SUITES${NC}"
echo ""

for result in "${SUITE_RESULTS[@]}"; do
    echo -e "$result"
done

echo ""

# Exit with appropriate code
if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}            🎉 ALL TEST SUITES PASSED! 🎉             ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}         ⚠️  SOME TEST SUITES FAILED ⚠️                ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    exit 1
fi