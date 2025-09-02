#!/bin/bash
# ABOUTME: Unit tests for encryption core functionality

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test utilities
source "$TEST_DIR/../helpers/test-utils.sh"

# Source encryption core
source "$PROJECT_DIR/hooks/lib/encryption-core.sh" 2>/dev/null || true

# Test environment setup
export TEST_TMP_DIR=$(mktemp -d)

test_basic_encryption_decryption() {
    test_start "Basic Encryption and Decryption"
    
    local test_data="This is sensitive data that needs encryption"
    local password="test_password_123"
    
    # Encrypt data
    local encrypted=$(encrypt_data "$test_data" "$password" 2>/dev/null)
    
    # Verify encrypted data is not plaintext
    if ! echo "$encrypted" | grep -q "$test_data"; then
        test_pass "Data properly encrypted"
    else
        test_fail "Data not encrypted (plaintext visible)"
        return 1
    fi
    
    # Decrypt data
    local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
    
    # Verify decryption
    if [ "$decrypted" = "$test_data" ]; then
        test_pass "Data correctly decrypted"
    else
        test_fail "Decryption failed or incorrect"
        echo "  Expected: $test_data"
        echo "  Got: $decrypted"
    fi
}

test_encryption_with_special_characters() {
    test_start "Encryption with Special Characters"
    
    local test_data='Special chars: !@#$%^&*()_+-=[]{}|;:"<>,.?/~`'
    local password="p@ssw0rd!#"
    
    # Encrypt and decrypt
    local encrypted=$(encrypt_data "$test_data" "$password" 2>/dev/null)
    local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
    
    if [ "$decrypted" = "$test_data" ]; then
        test_pass "Special characters handled correctly"
    else
        test_fail "Special character handling failed"
    fi
}

test_encryption_with_newlines() {
    test_start "Encryption with Newlines"
    
    local test_data="Line 1
Line 2
Line 3"
    local password="multiline_pass"
    
    # Encrypt and decrypt
    local encrypted=$(encrypt_data "$test_data" "$password" 2>/dev/null)
    local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
    
    if [ "$decrypted" = "$test_data" ]; then
        test_pass "Multiline data handled correctly"
    else
        test_fail "Multiline data handling failed"
    fi
}

test_wrong_password_decryption() {
    test_start "Wrong Password Decryption"
    
    local test_data="Secure data"
    local correct_password="correct_pass"
    local wrong_password="wrong_pass"
    
    # Encrypt with correct password
    local encrypted=$(encrypt_data "$test_data" "$correct_password" 2>/dev/null)
    
    # Try to decrypt with wrong password
    local decrypted=$(decrypt_data "$encrypted" "$wrong_password" 2>/dev/null)
    
    if [ "$decrypted" != "$test_data" ]; then
        test_pass "Wrong password rejected"
    else
        test_fail "Wrong password incorrectly accepted"
    fi
}

test_file_encryption_decryption() {
    test_start "File Encryption and Decryption"
    
    local test_file="$TEST_TMP_DIR/test_file.txt"
    local encrypted_file="$TEST_TMP_DIR/test_file.enc"
    local decrypted_file="$TEST_TMP_DIR/test_file_dec.txt"
    local password="file_password"
    
    # Create test file
    echo "File content to encrypt" > "$test_file"
    
    # Encrypt file
    if encrypt_file "$test_file" "$encrypted_file" "$password" 2>/dev/null; then
        test_pass "File encrypted successfully"
    else
        test_fail "File encryption failed"
        return 1
    fi
    
    # Verify encrypted file exists
    assert_file_exists "$encrypted_file" "Encrypted file created"
    
    # Decrypt file
    if decrypt_file "$encrypted_file" "$decrypted_file" "$password" 2>/dev/null; then
        test_pass "File decrypted successfully"
    else
        test_fail "File decryption failed"
        return 1
    fi
    
    # Compare original and decrypted
    if diff "$test_file" "$decrypted_file" > /dev/null; then
        test_pass "File content preserved"
    else
        test_fail "File content corrupted"
    fi
}

test_large_data_encryption() {
    test_start "Large Data Encryption"
    
    # Generate 1MB of random data
    local large_data=$(head -c 1048576 /dev/urandom | base64)
    local password="large_data_pass"
    
    # Measure encryption time
    local start=$(date +%s%N)
    local encrypted=$(encrypt_data "$large_data" "$password" 2>/dev/null)
    local end=$(date +%s%N)
    
    local duration_ms=$(((end - start) / 1000000))
    
    if [ -n "$encrypted" ]; then
        test_pass "Large data encrypted in ${duration_ms}ms"
    else
        test_fail "Large data encryption failed"
        return 1
    fi
    
    # Decrypt and verify
    local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
    
    if [ "$decrypted" = "$large_data" ]; then
        test_pass "Large data integrity maintained"
    else
        test_fail "Large data corruption detected"
    fi
}

test_empty_data_encryption() {
    test_start "Empty Data Encryption"
    
    local empty_data=""
    local password="empty_pass"
    
    # Try to encrypt empty data
    local encrypted=$(encrypt_data "$empty_data" "$password" 2>/dev/null)
    
    if [ -n "$encrypted" ]; then
        # Decrypt and verify
        local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
        
        if [ "$decrypted" = "$empty_data" ]; then
            test_pass "Empty data handled correctly"
        else
            test_fail "Empty data decryption failed"
        fi
    else
        test_pass "Empty data encryption handled"
    fi
}

test_encryption_key_derivation() {
    test_start "Encryption Key Derivation"
    
    local test_data="Key derivation test"
    local password1="password"
    local password2="password"  # Same password
    local password3="different"
    
    # Encrypt with same password twice
    local encrypted1=$(encrypt_data "$test_data" "$password1" 2>/dev/null)
    local encrypted2=$(encrypt_data "$test_data" "$password2" 2>/dev/null)
    
    # Encrypted data should be different due to salt
    if [ "$encrypted1" != "$encrypted2" ]; then
        test_pass "Salt ensures unique encryption"
    else
        test_fail "Encryption not using salt properly"
    fi
    
    # Both should decrypt to same data
    local decrypted1=$(decrypt_data "$encrypted1" "$password1" 2>/dev/null)
    local decrypted2=$(decrypt_data "$encrypted2" "$password2" 2>/dev/null)
    
    if [ "$decrypted1" = "$test_data" ] && [ "$decrypted2" = "$test_data" ]; then
        test_pass "Both decrypt correctly despite different ciphertext"
    else
        test_fail "Decryption inconsistency"
    fi
}

test_concurrent_encryption() {
    test_start "Concurrent Encryption Operations"
    
    local password="concurrent_pass"
    
    # Function for concurrent encryption
    encrypt_concurrent() {
        local id=$1
        local data="Thread $id data"
        local encrypted=$(encrypt_data "$data" "$password" 2>/dev/null)
        local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
        
        if [ "$decrypted" = "$data" ]; then
            return 0
        else
            return 1
        fi
    }
    
    # Run concurrent encryptions
    if run_concurrent_tests encrypt_concurrent 10; then
        test_pass "Concurrent encryption handled"
    else
        test_fail "Concurrent encryption failed"
    fi
}

test_base64_encoding_validation() {
    test_start "Base64 Encoding Validation"
    
    local test_data="Base64 test data"
    local password="base64_pass"
    
    # Encrypt data
    local encrypted=$(encrypt_data "$test_data" "$password" 2>/dev/null)
    
    # Verify valid base64
    if echo "$encrypted" | base64 -d > /dev/null 2>&1; then
        test_pass "Encrypted data is valid base64"
    else
        test_fail "Encrypted data not valid base64"
    fi
    
    # Corrupt base64 and try to decrypt
    local corrupted="${encrypted}corrupted"
    local decrypted=$(decrypt_data "$corrupted" "$password" 2>/dev/null)
    
    if [ "$decrypted" != "$test_data" ]; then
        test_pass "Corrupted base64 handled gracefully"
    else
        test_fail "Corrupted base64 not detected"
    fi
}

test_password_complexity_handling() {
    test_start "Password Complexity Handling"
    
    local test_data="Password complexity test"
    
    # Test various password complexities
    local passwords=(
        "a"  # Single character
        "12345678901234567890123456789012"  # 32 characters
        "🔐🔑🗝️"  # Unicode emojis
        "パスワード"  # Japanese characters
        "\$\`\\\"'"  # Shell special characters
    )
    
    local all_passed=true
    
    for password in "${passwords[@]}"; do
        local encrypted=$(encrypt_data "$test_data" "$password" 2>/dev/null)
        
        if [ -n "$encrypted" ]; then
            local decrypted=$(decrypt_data "$encrypted" "$password" 2>/dev/null)
            
            if [ "$decrypted" != "$test_data" ]; then
                all_passed=false
                echo "  Failed with password: $password"
            fi
        else
            all_passed=false
            echo "  Encryption failed with password: $password"
        fi
    done
    
    if $all_passed; then
        test_pass "All password complexities handled"
    else
        test_fail "Some password complexities failed"
    fi
}

# Cleanup function
cleanup_encryption_tests() {
    rm -rf "$TEST_TMP_DIR"
}

# Run all tests
run_all_encryption_tests() {
    echo "Encryption Core Unit Tests"
    echo "========================="
    
    test_basic_encryption_decryption
    test_encryption_with_special_characters
    test_encryption_with_newlines
    test_wrong_password_decryption
    test_file_encryption_decryption
    test_large_data_encryption
    test_empty_data_encryption
    test_encryption_key_derivation
    test_concurrent_encryption
    test_base64_encoding_validation
    test_password_complexity_handling
    
    cleanup_encryption_tests
    
    test_summary
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_encryption_tests
fi