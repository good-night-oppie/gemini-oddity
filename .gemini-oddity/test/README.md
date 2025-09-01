# Gemini Oddity Test Suite

## Overview

This directory contains the test suite for the gemini-oddity project. All tests are written in Bash and follow Test-Driven Development (TDD) principles.

## Test Structure

```
test/
├── run-tests.sh         # Main test runner
├── helpers/
│   └── test-framework.sh # Test framework with assertions
├── unit/               # Unit tests for individual components
├── integration/        # Integration tests for full workflows
└── fixtures/          # Test data and mock files
```

## Running Tests

### Run all tests
```bash
./test/run-tests.sh
```

### Run only unit tests
```bash
./test/run-tests.sh --unit
```

### Run only integration tests
```bash
./test/run-tests.sh --integration
```

### Run tests with verbose output
```bash
./test/run-tests.sh --verbose
```

### Run tests matching a pattern
```bash
./test/run-tests.sh --pattern oauth
```

## Writing Tests

### Basic Test Structure

```bash
#!/bin/bash
# Source the test framework
source "$(dirname "$0")/../helpers/test-framework.sh"

# Describe your test suite
describe "My Component"

# Define test functions
test_my_feature() {
    # Arrange
    local input="test"
    
    # Act
    local result=$(my_function "$input")
    
    # Assert
    assert_equals "expected" "$result" "Should return expected value"
}

# Register the test
it "should do something" test_my_feature
```

### Available Assertions

- `assert_equals expected actual [message]` - Check equality
- `assert_not_equals unexpected actual [message]` - Check inequality
- `assert_true condition [message]` - Check condition is true
- `assert_false condition [message]` - Check condition is false
- `assert_contains haystack needle [message]` - Check string contains substring
- `assert_not_contains haystack needle [message]` - Check string doesn't contain substring
- `assert_file_exists file [message]` - Check file exists
- `assert_file_not_exists file [message]` - Check file doesn't exist
- `assert_directory_exists dir [message]` - Check directory exists
- `assert_exit_code expected actual [message]` - Check exit code
- `assert_valid_json json [message]` - Check valid JSON
- `assert_json_field_equals json field expected [message]` - Check JSON field value

### Setup and Teardown

```bash
# Define setup function
test_setup() {
    # Create test environment
    export TEST_VAR="value"
}

# Define teardown function
test_teardown() {
    # Clean up after test
    unset TEST_VAR
}

# Register them
setup test_setup
teardown test_teardown
```

### Mocking

```bash
# Mock a function
mock_function "function_name" "mock output" 0  # name, output, exit code

# Use the mocked function
result=$(function_name)

# Restore original function
restore_function "function_name"

# Stub a command
stub_command "git" 'echo "mocked git output"'

# Clean up stubs
cleanup_stubs
```

## Test Conventions

1. **File Naming**: Test files must end with `_test.sh`
2. **Location**: 
   - Unit tests go in `test/unit/`
   - Integration tests go in `test/integration/`
3. **One test file per source file**: `hooks/lib/foo.sh` → `test/unit/foo_test.sh`
4. **Descriptive test names**: Use `it "should..."` format
5. **Arrange-Act-Assert**: Structure tests clearly
6. **Isolated tests**: Each test should be independent
7. **Clean up**: Always clean up temporary files and state

## TDD Workflow

With TDD-guard enabled, you must:

1. Write a failing test first (RED phase)
2. Write implementation to make it pass (GREEN phase)
3. Refactor if needed (REFACTOR phase)

The TDD-guard hooks enforce this workflow automatically.

## Common Test Patterns

### Testing Functions That Read Files

```bash
test_file_reader() {
    # Create temp file
    local temp_file=$(mktemp)
    echo "test content" > "$temp_file"
    
    # Test function
    local result=$(read_file "$temp_file")
    
    # Assert and clean up
    assert_equals "test content" "$result"
    rm -f "$temp_file"
}
```

### Testing Functions That Call External Commands

```bash
test_git_caller() {
    # Stub git command
    stub_command "git" 'echo "main"'
    
    # Test function that calls git
    local branch=$(get_current_branch)
    
    # Assert
    assert_equals "main" "$branch"
    
    # Clean up
    cleanup_stubs
}
```

### Testing Error Handling

```bash
test_error_handling() {
    # Test with invalid input
    local result=$(my_function "invalid" 2>&1)
    local exit_code=$?
    
    # Assert error occurred
    assert_not_equals 0 "$exit_code" "Should fail with invalid input"
    assert_contains "$result" "Error:" "Should output error message"
}
```

## Continuous Integration

Tests are automatically run:
- On every commit (via git hooks)
- In CI/CD pipeline
- Before releases

## Debugging Tests

### Enable verbose output
```bash
VERBOSE=1 ./test/run-tests.sh
```

### Run specific test file
```bash
bash test/unit/specific_test.sh
```

### Add debug output
```bash
test_something() {
    local result=$(my_function)
    echo "Debug: result='$result'" >&2  # Output to stderr
    assert_equals "expected" "$result"
}
```