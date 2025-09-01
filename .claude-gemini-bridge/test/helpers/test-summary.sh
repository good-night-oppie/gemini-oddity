#!/bin/bash
# ABOUTME: Simple test summary reporter

# This should be called at the end of each test file
print_test_summary() {
    echo
    echo "Test Results:"
    echo "============="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo
        echo "✅ All tests passed!"
        return 0
    else
        echo
        echo "❌ Some tests failed!"
        return 1
    fi
}