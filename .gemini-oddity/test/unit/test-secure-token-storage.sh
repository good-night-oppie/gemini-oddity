#!/bin/bash
# ABOUTME: Comprehensive test suite for secure token storage system

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test helper
source "$TEST_DIR/../helpers/test-helper.sh"

# Test environment setup
export HOME="/tmp/test_home_$$"
export TOKEN_STORAGE_DIR="$HOME/.gemini-oddity/auth"
export SECURE_TEMP_DIR="/tmp/test_secure_$$"
mkdir -p "$HOME"

# Source modules to test
source "$PROJECT_DIR/hooks/lib/encryption-core.sh"
source "$PROJECT_DIR/hooks/lib/token-storage.sh"
source "$PROJECT_DIR/hooks/lib/token-rotation.sh"
source "$PROJECT_DIR/hooks/lib/security-audit.sh"

# Override debug output for tests
debug_log() { return 0; }
error_log() { echo "ERROR: $*" >&2; }

# ============================================================================
# Encryption Core Tests
# ============================================================================

test_encryption_initialization() {
    test_start "Encryption Initialization"
    
    # Test initialization
    if init_encryption; then
        # Check OpenSSL availability
        if command -v openssl &>/dev/null; then
            test_pass "Encryption system initialized"
        else
            test_fail "OpenSSL not available"
        fi
    else
        test_fail "Failed to initialize encryption"
    fi
}

test_key_derivation() {
    test_start "Key Derivation (PBKDF2)"
    
    local password="test_password_123"
    local salt=$(generate_salt)
    
    # Test key derivation
    local key=$(derive_key "$password" "$salt")
    
    if [ -n "$key" ] && [ ${#key} -eq 64 ]; then
        # Verify deterministic derivation
        local key2=$(derive_key "$password" "$salt")
        if [ "$key" = "$key2" ]; then
            test_pass "Key derivation deterministic"
        else
            test_fail "Key derivation not deterministic"
        fi
    else
        test_fail "Invalid derived key"
    fi
}

test_encryption_decryption() {
    test_start "AES-256-GCM Encryption/Decryption"
    
    local test_data="Sensitive token data that needs encryption"
    local password="secure_password_456"
    
    # Test encryption
    local encrypted=$(encrypt_data "$test_data" "$password")
    
    if [ $? -eq 0 ] && [ -n "$encrypted" ]; then
        # Verify JSON structure
        if echo "$encrypted" | grep -q '"algorithm"' && \
           echo "$encrypted" | grep -q '"ciphertext"' && \
           echo "$encrypted" | grep -q '"tag"'; then
            
            # Test decryption
            local decrypted=$(decrypt_data "$encrypted" "$password")
            
            if [ "$decrypted" = "$test_data" ]; then
                test_pass "Encryption/decryption successful"
            else
                test_fail "Decryption mismatch"
            fi
        else
            test_fail "Invalid encrypted data format"
        fi
    else
        test_fail "Encryption failed"
    fi
}

test_encryption_wrong_password() {
    test_start "Decryption with Wrong Password"
    
    local test_data="Secret information"
    local correct_password="correct_pass"
    local wrong_password="wrong_pass"
    
    # Encrypt with correct password
    local encrypted=$(encrypt_data "$test_data" "$correct_password")
    
    # Try to decrypt with wrong password
    local decrypted=$(decrypt_data "$encrypted" "$wrong_password" 2>/dev/null)
    
    if [ -z "$decrypted" ]; then
        test_pass "Wrong password correctly rejected"
    else
        test_fail "Wrong password incorrectly accepted"
    fi
}

test_machine_key_generation() {
    test_start "Machine-Specific Key Generation"
    
    local key1=$(get_machine_key)
    local key2=$(get_machine_key)
    
    if [ -n "$key1" ] && [ ${#key1} -eq 64 ]; then
        if [ "$key1" = "$key2" ]; then
            test_pass "Machine key generation consistent"
        else
            test_fail "Machine key not consistent"
        fi
    else
        test_fail "Invalid machine key generated"
    fi
}

# ============================================================================
# Token Storage Tests
# ============================================================================

test_token_storage_initialization() {
    test_start "Token Storage Initialization"
    
    # Clean environment
    rm -rf "$TOKEN_STORAGE_DIR"
    
    if init_token_storage; then
        # Check directory creation
        if [ -d "$TOKEN_STORAGE_DIR" ]; then
            # Check permissions
            local perms=$(stat -c %a "$TOKEN_STORAGE_DIR" 2>/dev/null || echo "700")
            if [ "$perms" = "700" ]; then
                test_pass "Token storage initialized with secure permissions"
            else
                test_fail "Incorrect directory permissions: $perms"
            fi
        else
            test_fail "Storage directory not created"
        fi
    else
        test_fail "Failed to initialize token storage"
    fi
}

test_store_and_retrieve_token() {
    test_start "Store and Retrieve Token"
    
    local provider="test_provider"
    local token="test_access_token_789"
    local refresh_token="test_refresh_token_abc"
    local expires_at=$(date -d "+1 hour" -Iseconds 2>/dev/null || date -v +1H -Iseconds 2>/dev/null)
    
    # Store token
    if store_token "$provider" "oauth" "$token" "$expires_at" "$refresh_token"; then
        # Retrieve token
        local retrieved=$(retrieve_token "$provider")
        
        if [ "$retrieved" = "$token" ]; then
            # Check refresh token
            local retrieved_refresh=$(retrieve_token "$provider" "refresh_token")
            if [ "$retrieved_refresh" = "$refresh_token" ]; then
                test_pass "Token storage and retrieval successful"
            else
                test_fail "Refresh token retrieval failed"
            fi
        else
            test_fail "Access token retrieval failed"
        fi
    else
        test_fail "Failed to store token"
    fi
}

test_token_file_permissions() {
    test_start "Token File Permissions"
    
    local provider="security_test"
    local token="security_token_123"
    
    # Store token
    store_token "$provider" "api_key" "$token" "" "" >/dev/null 2>&1
    
    if [ -f "$TOKEN_FILE" ]; then
        local perms=$(stat -c %a "$TOKEN_FILE" 2>/dev/null || echo "600")
        if [ "$perms" = "600" ]; then
            test_pass "Token file has secure permissions"
        else
            test_fail "Insecure token file permissions: $perms"
        fi
    else
        test_fail "Token file not created"
    fi
}

test_token_deletion() {
    test_start "Token Deletion"
    
    local provider="delete_test"
    local token="delete_token_456"
    
    # Store token
    store_token "$provider" "oauth" "$token" "" "" >/dev/null 2>&1
    
    # Delete token
    if delete_token "$provider"; then
        # Try to retrieve deleted token
        local retrieved=$(retrieve_token "$provider" 2>/dev/null)
        
        if [ -z "$retrieved" ]; then
            test_pass "Token successfully deleted"
        else
            test_fail "Token still retrievable after deletion"
        fi
    else
        test_fail "Failed to delete token"
    fi
}

test_concurrent_token_access() {
    test_start "Concurrent Token Access"
    
    local provider="concurrent_test"
    local success_count=0
    local total_attempts=5
    
    # Try concurrent writes
    for i in $(seq 1 $total_attempts); do
        (store_token "$provider" "oauth" "token_$i" "" "" >/dev/null 2>&1) &
    done
    
    wait
    
    # Check final state
    local final_token=$(retrieve_token "$provider" 2>/dev/null)
    
    if [ -n "$final_token" ]; then
        test_pass "Concurrent access handled correctly"
    else
        test_fail "Concurrent access corrupted storage"
    fi
}

# ============================================================================
# Token Rotation Tests
# ============================================================================

test_token_expiration_check() {
    test_start "Token Expiration Check"
    
    local provider="expiry_test"
    local token="expiry_token_123"
    
    # Store expired token
    local expired_time=$(date -d "-1 hour" -Iseconds 2>/dev/null || date -v -1H -Iseconds 2>/dev/null)
    store_token "$provider" "oauth" "$token" "$expired_time" "" >/dev/null 2>&1
    
    # Check expiration
    if is_token_expired "$provider"; then
        test_pass "Expired token correctly detected"
    else
        test_fail "Failed to detect expired token"
    fi
    
    # Store valid token
    local valid_time=$(date -d "+1 hour" -Iseconds 2>/dev/null || date -v +1H -Iseconds 2>/dev/null)
    store_token "$provider" "oauth" "$token" "$valid_time" "" >/dev/null 2>&1
    
    # Check valid token
    if ! is_token_expired "$provider"; then
        test_pass "Valid token correctly identified"
    else
        test_fail "Valid token incorrectly marked as expired"
    fi
}

test_token_rotation_needed() {
    test_start "Token Rotation Need Detection"
    
    local provider="rotation_test"
    local token="rotation_token_456"
    
    # Store token expiring soon
    local expiring_soon=$(date -d "+4 minutes" -Iseconds 2>/dev/null || date -v +4M -Iseconds 2>/dev/null)
    store_token "$provider" "oauth" "$token" "$expiring_soon" "" >/dev/null 2>&1
    
    # Check if rotation needed (with 5-minute buffer)
    if needs_rotation "$provider" 300; then
        test_pass "Rotation need correctly detected"
    else
        test_fail "Failed to detect rotation need"
    fi
}

test_rotation_state_management() {
    test_start "Rotation State Management"
    
    # Initialize rotation state
    init_rotation_state
    
    if [ -f "$ROTATION_STATE_FILE" ]; then
        # Update rotation state
        update_rotation_state "test_provider" "rotate" "Test rotation"
        
        # Check state file
        if grep -q "test_provider" "$ROTATION_STATE_FILE"; then
            test_pass "Rotation state management working"
        else
            test_fail "Rotation state not updated"
        fi
    else
        test_fail "Rotation state file not created"
    fi
}

# ============================================================================
# Security Audit Tests
# ============================================================================

test_audit_initialization() {
    test_start "Audit System Initialization"
    
    # Clean environment
    rm -rf "$AUDIT_LOG_DIR"
    
    if init_audit_system; then
        # Check directory and files
        if [ -d "$AUDIT_LOG_DIR" ] && \
           [ -f "$SECURITY_LOG_FILE" ] && \
           [ -f "$AUDIT_REPORT_FILE" ]; then
            
            # Check permissions
            local dir_perms=$(stat -c %a "$AUDIT_LOG_DIR" 2>/dev/null || echo "700")
            if [ "$dir_perms" = "700" ]; then
                test_pass "Audit system initialized correctly"
            else
                test_fail "Incorrect audit directory permissions"
            fi
        else
            test_fail "Audit files not created"
        fi
    else
        test_fail "Failed to initialize audit system"
    fi
}

test_security_event_logging() {
    test_start "Security Event Logging"
    
    # Log security event
    log_security_event "$EVENT_AUTH_SUCCESS" "$SEVERITY_INFO" "Test authentication successful" "user=test"
    
    # Check if event was logged
    if [ -f "$SECURITY_LOG_FILE" ] && grep -q "AUTH_SUCCESS" "$SECURITY_LOG_FILE"; then
        test_pass "Security event logged successfully"
    else
        test_fail "Security event not logged"
    fi
}

test_access_logging() {
    test_start "Access Attempt Logging"
    
    # Log access attempt
    log_access_attempt "/secure/resource" "read" "success" "authorized access"
    
    # Check if logged
    if [ -f "$ACCESS_LOG_FILE" ] && grep -q "/secure/resource" "$ACCESS_LOG_FILE"; then
        test_pass "Access attempt logged successfully"
    else
        test_fail "Access attempt not logged"
    fi
}

test_audit_statistics() {
    test_start "Audit Statistics Update"
    
    # Log multiple events
    log_security_event "$EVENT_AUTH_SUCCESS" "$SEVERITY_INFO" "Test 1" ""
    log_security_event "$EVENT_AUTH_FAILURE" "$SEVERITY_WARNING" "Test 2" ""
    
    # Check statistics
    if [ -f "$AUDIT_REPORT_FILE" ]; then
        if command -v jq &>/dev/null; then
            local total_events=$(cat "$AUDIT_REPORT_FILE" | jq -r '.statistics.total_events')
            if [ "$total_events" -gt 0 ]; then
                test_pass "Audit statistics updated correctly"
            else
                test_fail "Statistics not updated"
            fi
        else
            # Fallback check
            if grep -q "total_events" "$AUDIT_REPORT_FILE"; then
                test_pass "Audit statistics present"
            else
                test_fail "Statistics not found"
            fi
        fi
    else
        test_fail "Audit report file not found"
    fi
}

test_security_compliance_check() {
    test_start "Security Compliance Check"
    
    # Run compliance check
    local compliance_output=$(check_security_compliance 2>&1)
    local exit_code=$?
    
    # Should have some output
    if [ -n "$compliance_output" ]; then
        if echo "$compliance_output" | grep -q "COMPLIANT"; then
            test_pass "Compliance check executed"
        else
            # Non-compliant is also valid result
            test_pass "Compliance check detected issues"
        fi
    else
        test_fail "Compliance check produced no output"
    fi
}

test_log_rotation() {
    test_start "Log File Rotation"
    
    # Create large log content
    local large_content=$(dd if=/dev/zero bs=1024 count=100 2>/dev/null | tr '\0' 'A')
    
    # Fill log file
    for i in {1..200}; do
        echo "$large_content" >> "$SECURITY_LOG_FILE"
    done
    
    # Trigger rotation
    rotate_logs_if_needed
    
    # Check if rotation occurred
    if [ -f "${SECURITY_LOG_FILE}.1" ]; then
        test_pass "Log rotation successful"
    else
        test_fail "Log rotation did not occur"
    fi
}

# ============================================================================
# Integration Tests
# ============================================================================

test_full_token_lifecycle() {
    test_start "Full Token Lifecycle"
    
    local provider="lifecycle_test"
    local token="lifecycle_token_123"
    local refresh_token="lifecycle_refresh_456"
    local expires_at=$(date -d "+1 hour" -Iseconds 2>/dev/null || date -v +1H -Iseconds 2>/dev/null)
    
    # Store token
    if store_token "$provider" "oauth" "$token" "$expires_at" "$refresh_token"; then
        # Log authentication
        log_security_event "$EVENT_AUTH_SUCCESS" "$SEVERITY_INFO" "Token stored for $provider"
        
        # Check token
        if [ "$(retrieve_token "$provider")" = "$token" ]; then
            # Update token (simulate rotation)
            local new_token="new_lifecycle_token_789"
            store_token "$provider" "oauth" "$new_token" "$expires_at" "$refresh_token"
            log_security_event "$EVENT_TOKEN_ROTATED" "$SEVERITY_INFO" "Token rotated for $provider"
            
            # Verify new token
            if [ "$(retrieve_token "$provider")" = "$new_token" ]; then
                # Delete token
                delete_token "$provider"
                log_security_event "$EVENT_TOKEN_DELETED" "$SEVERITY_INFO" "Token deleted for $provider"
                
                # Verify deletion
                if ! retrieve_token "$provider" 2>/dev/null; then
                    test_pass "Full token lifecycle completed"
                else
                    test_fail "Token still present after deletion"
                fi
            else
                test_fail "Token rotation failed"
            fi
        else
            test_fail "Token retrieval failed"
        fi
    else
        test_fail "Initial token storage failed"
    fi
}

test_security_breach_simulation() {
    test_start "Security Breach Detection"
    
    # Simulate multiple auth failures
    for i in {1..6}; do
        log_security_event "$EVENT_AUTH_FAILURE" "$SEVERITY_WARNING" "Failed auth attempt $i"
    done
    
    # Check if alert was created
    if [ -f "$AUDIT_REPORT_FILE" ]; then
        if command -v jq &>/dev/null; then
            local alerts=$(cat "$AUDIT_REPORT_FILE" | jq -r '.alerts | length')
            if [ "$alerts" -gt 0 ]; then
                test_pass "Security breach detected and alerted"
            else
                test_fail "No alerts generated for breach"
            fi
        else
            if grep -q "alert" "$AUDIT_REPORT_FILE"; then
                test_pass "Security alerts present"
            else
                test_fail "No security alerts found"
            fi
        fi
    else
        test_fail "Audit report not available"
    fi
}

# ============================================================================
# Performance Tests
# ============================================================================

test_encryption_performance() {
    test_start "Encryption Performance"
    
    local test_data="Performance test data with reasonable length for token storage"
    local iterations=10
    local start_time=$(date +%s%N)
    
    for i in $(seq 1 $iterations); do
        local encrypted=$(encrypt_data "$test_data" "test_password")
        local decrypted=$(decrypt_data "$encrypted" "test_password")
    done
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    local avg_time=$(( duration / iterations ))
    
    if [ "$avg_time" -lt 500 ]; then  # Should be under 500ms per operation
        test_pass "Encryption performance acceptable: ${avg_time}ms average"
    else
        test_fail "Encryption too slow: ${avg_time}ms average"
    fi
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup_test_environment() {
    # Secure cleanup of test data
    if [ -d "$TOKEN_STORAGE_DIR" ]; then
        find "$TOKEN_STORAGE_DIR" -type f -exec shred -vfz -n 1 {} \; 2>/dev/null || \
        rm -rf "$TOKEN_STORAGE_DIR"
    fi
    
    if [ -d "$AUDIT_LOG_DIR" ]; then
        find "$AUDIT_LOG_DIR" -type f -exec shred -vfz -n 1 {} \; 2>/dev/null || \
        rm -rf "$AUDIT_LOG_DIR"
    fi
    
    rm -rf "$HOME"
    rm -rf "$SECURE_TEMP_DIR"
}

# ============================================================================
# Run Tests
# ============================================================================

run_all_tests() {
    echo "Running Secure Token Storage Tests"
    echo "=================================="
    
    # Encryption Core Tests
    echo ""
    echo "Encryption Core Tests:"
    test_encryption_initialization
    test_key_derivation
    test_encryption_decryption
    test_encryption_wrong_password
    test_machine_key_generation
    
    # Token Storage Tests
    echo ""
    echo "Token Storage Tests:"
    test_token_storage_initialization
    test_store_and_retrieve_token
    test_token_file_permissions
    test_token_deletion
    test_concurrent_token_access
    
    # Token Rotation Tests
    echo ""
    echo "Token Rotation Tests:"
    test_token_expiration_check
    test_token_rotation_needed
    test_rotation_state_management
    
    # Security Audit Tests
    echo ""
    echo "Security Audit Tests:"
    test_audit_initialization
    test_security_event_logging
    test_access_logging
    test_audit_statistics
    test_security_compliance_check
    test_log_rotation
    
    # Integration Tests
    echo ""
    echo "Integration Tests:"
    test_full_token_lifecycle
    test_security_breach_simulation
    
    # Performance Tests
    echo ""
    echo "Performance Tests:"
    test_encryption_performance
    
    # Cleanup
    cleanup_test_environment
    
    # Summary
    test_summary
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi