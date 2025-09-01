#!/bin/bash
# ABOUTME: Test the test framework itself

# Source test framework
source "$(dirname "$0")/../helpers/test-framework.sh"

# Test suite for the test framework
describe "Test Framework"

test_equality() {
    assert_equals "hello" "hello" "Strings should be equal"
    assert_equals 42 42 "Numbers should be equal"
}
it "should pass equality assertions" test_equality

test_inequality() {
    assert_not_equals "hello" "world" "Different strings"
    assert_not_equals 42 43 "Different numbers"
}
it "should pass inequality assertions" test_inequality

test_booleans() {
    assert_true "[ 1 -eq 1 ]" "One equals one"
    assert_false "[ 1 -eq 2 ]" "One does not equal two"
}
it "should pass boolean assertions" test_booleans

test_contains() {
    assert_contains "hello world" "world" "Should contain substring"
    assert_not_contains "hello world" "foo" "Should not contain substring"
}
it "should pass string contains assertions" test_contains

test_files() {
    # Create a temp file
    local temp_file=$(mktemp)
    assert_file_exists "$temp_file" "Temp file should exist"
    
    rm -f "$temp_file"
    assert_file_not_exists "$temp_file" "Deleted file should not exist"
}
it "should handle file assertions" test_files

test_directories() {
    assert_directory_exists "/tmp" "Tmp directory should exist"
}
it "should handle directory assertions" test_directories

test_exit_codes() {
    assert_exit_code 0 0 "Zero exit codes should match"
    assert_exit_code 1 1 "Non-zero exit codes should match"
}
it "should handle exit code assertions" test_exit_codes

# Test setup and teardown
TEST_SETUP_RAN=0
TEST_TEARDOWN_RAN=0

test_setup() {
    TEST_SETUP_RAN=1
}

test_teardown() {
    TEST_TEARDOWN_RAN=1
}

describe "Setup and Teardown"

setup test_setup
teardown test_teardown

test_setup_runs() {
    assert_equals 1 "$TEST_SETUP_RAN" "Setup should have run"
}
it "should run setup before test" test_setup_runs

# Reset for next test
setup ""
teardown ""

# Test mocking
describe "Mocking Functions"

test_mocking() {
    # Define a function to mock
    original_function() {
        echo "original"
        return 0
    }
    
    # Mock it
    mock_function original_function "mocked" 42
    
    local output=$(original_function)
    local exit_code=$?
    
    assert_equals "mocked" "$output" "Should return mocked output"
    assert_equals 42 "$exit_code" "Should return mocked exit code"
    
    # Restore it
    restore_function original_function
    
    output=$(original_function)
    assert_equals "original" "$output" "Should return original output after restore"
}
it "should mock functions" test_mocking