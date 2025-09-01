#!/bin/bash
# ABOUTME: Security audit and vulnerability testing

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test utilities
source "$TEST_DIR/../helpers/test-utils.sh"

# Security test configuration
SECURITY_ISSUES=()

test_file_permissions() {
    test_start "File Permission Security Audit"
    
    local issues_found=0
    
    # Check token directory permissions
    if [ -d "$HOME/.claude-gemini-bridge/tokens" ]; then
        local perm=$(stat -c %a "$HOME/.claude-gemini-bridge/tokens" 2>/dev/null || stat -f %A "$HOME/.claude-gemini-bridge/tokens" 2>/dev/null)
        if [ "$perm" != "700" ]; then
            SECURITY_ISSUES+=("Token directory has insecure permissions: $perm (should be 700)")
            ((issues_found++))
        fi
    fi
    
    # Check for world-readable sensitive files
    local sensitive_patterns=(
        "*.key"
        "*.pem"
        "*.enc"
        "*token*"
        "*secret*"
        "*password*"
        "config.json"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                local perm=$(stat -c %a "$file" 2>/dev/null || stat -f %A "$file" 2>/dev/null)
                if [[ "$perm" == *[4567] ]]; then  # World-readable
                    SECURITY_ISSUES+=("World-readable sensitive file: $file (permissions: $perm)")
                    ((issues_found++))
                fi
            fi
        done < <(find "$PROJECT_DIR" -name "$pattern" 2>/dev/null)
    done
    
    if [ $issues_found -eq 0 ]; then
        test_pass "No file permission issues found"
    else
        test_fail "$issues_found file permission issues found"
    fi
}

test_secret_exposure() {
    test_start "Secret Exposure in Code"
    
    local issues_found=0
    
    # Patterns that indicate potential secrets
    local secret_patterns=(
        'api[_-]?key.*=.*["\047][^"\047]{20,}["\047]'
        'secret.*=.*["\047][^"\047]{20,}["\047]'
        'password.*=.*["\047][^"\047]{8,}["\047]'
        'token.*=.*["\047][^"\047]{20,}["\047]'
        'AIza[0-9A-Za-z_-]{35}'  # Google API key
        'ya29\.[0-9A-Za-z_-]+'   # Google OAuth token
        'AKIA[0-9A-Z]{16}'       # AWS Access Key
        'client_secret.*=.*["\047][^"\047]+'
    )
    
    # Exclude test files and documentation
    local exclude_dirs="-path '*/test/*' -prune -o -path '*/docs/*' -prune -o"
    
    for pattern in "${secret_patterns[@]}"; do
        while IFS= read -r match; do
            if [ -n "$match" ]; then
                local file=$(echo "$match" | cut -d: -f1)
                local line=$(echo "$match" | cut -d: -f2-)
                SECURITY_ISSUES+=("Potential secret in $file: $line")
                ((issues_found++))
            fi
        done < <(find "$PROJECT_DIR" $exclude_dirs -type f -name "*.sh" -o -name "*.json" | xargs grep -E "$pattern" 2>/dev/null || true)
    done
    
    if [ $issues_found -eq 0 ]; then
        test_pass "No secrets exposed in code"
    else
        test_fail "$issues_found potential secrets found"
    fi
}

test_command_injection() {
    test_start "Command Injection Vulnerabilities"
    
    local issues_found=0
    
    # Dangerous patterns that could lead to command injection
    local dangerous_patterns=(
        'eval[[:space:]]*\$'
        'eval[[:space:]]*\`'
        '\$\([^)]*\$[^)]*\)'  # Command substitution with variables
        'bash[[:space:]]*-c[[:space:]]*["'\'']*\$'
        'sh[[:space:]]*-c[[:space:]]*["'\'']*\$'
        'system[[:space:]]*\('
        'exec[[:space:]]*\$'
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        while IFS= read -r match; do
            if [ -n "$match" ]; then
                local file=$(echo "$match" | cut -d: -f1)
                local line_num=$(echo "$match" | cut -d: -f2)
                local line=$(echo "$match" | cut -d: -f3-)
                
                # Check if it's properly sanitized
                if ! echo "$line" | grep -q '# sanitized\|# safe\|# validated'; then
                    SECURITY_ISSUES+=("Potential command injection in $file:$line_num")
                    ((issues_found++))
                fi
            fi
        done < <(grep -rn -E "$pattern" "$PROJECT_DIR/hooks" 2>/dev/null || true)
    done
    
    if [ $issues_found -eq 0 ]; then
        test_pass "No command injection vulnerabilities found"
    else
        test_fail "$issues_found potential command injection points"
    fi
}

test_log_security() {
    test_start "Log Security Audit"
    
    local issues_found=0
    
    # Check for sensitive data in logs
    local log_dir="$PROJECT_DIR/logs"
    
    if [ -d "$log_dir" ]; then
        local sensitive_in_logs=(
            "password"
            "token"
            "secret"
            "api_key"
            "client_secret"
        )
        
        for term in "${sensitive_in_logs[@]}"; do
            if grep -ri "$term" "$log_dir" 2>/dev/null | grep -v "REDACTED\|hidden\|masked" > /dev/null; then
                SECURITY_ISSUES+=("Sensitive term '$term' found in logs")
                ((issues_found++))
            fi
        done
    fi
    
    if [ $issues_found -eq 0 ]; then
        test_pass "No sensitive data in logs"
    else
        test_fail "$issues_found sensitive terms in logs"
    fi
}

test_encryption_strength() {
    test_start "Encryption Strength Validation"
    
    local issues_found=0
    
    # Check encryption algorithm usage
    if grep -r "des\|rc4\|md5" "$PROJECT_DIR/hooks" 2>/dev/null | grep -v "aes-256-cbc" > /dev/null; then
        SECURITY_ISSUES+=("Weak encryption algorithm detected")
        ((issues_found++))
    fi
    
    # Check for hardcoded encryption keys
    if grep -r "ENCRYPTION_KEY\|ENCRYPTION_PASSWORD" "$PROJECT_DIR/hooks" 2>/dev/null | grep "=" | grep -v "\$" > /dev/null; then
        SECURITY_ISSUES+=("Hardcoded encryption key detected")
        ((issues_found++))
    fi
    
    # Verify AES-256-CBC is used
    if ! grep -r "aes-256-cbc" "$PROJECT_DIR/hooks/lib/encryption-core.sh" > /dev/null; then
        SECURITY_ISSUES+=("AES-256-CBC not found in encryption core")
        ((issues_found++))
    fi
    
    if [ $issues_found -eq 0 ]; then
        test_pass "Encryption properly configured"
    else
        test_fail "$issues_found encryption issues"
    fi
}

test_input_validation() {
    test_start "Input Validation Security"
    
    local issues_found=0
    
    # Check for unvalidated user input
    local unsafe_patterns=(
        'read[[:space:]]*-r[[:space:]]*[^;]*\$'  # Direct use of read input
        'curl.*\$[^{]'  # Unescaped variables in curl
        'wget.*\$[^{]'  # Unescaped variables in wget
    )
    
    for pattern in "${unsafe_patterns[@]}"; do
        local count=$(grep -r "$pattern" "$PROJECT_DIR/hooks" 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            SECURITY_ISSUES+=("$count instances of potentially unvalidated input")
            issues_found=$((issues_found + count))
        fi
    done
    
    if [ $issues_found -eq 0 ]; then
        test_pass "Input validation appears secure"
    else
        test_fail "$issues_found input validation concerns"
    fi
}

test_dependency_security() {
    test_start "Dependency Security Check"
    
    local issues_found=0
    
    # Check for unsafe curl/wget options
    if grep -r "curl.*--insecure\|wget.*--no-check-certificate" "$PROJECT_DIR" 2>/dev/null > /dev/null; then
        SECURITY_ISSUES+=("Insecure HTTP requests detected")
        ((issues_found++))
    fi
    
    # Check for HTTP instead of HTTPS
    if grep -r "http://[^l]" "$PROJECT_DIR/hooks" 2>/dev/null | grep -v "localhost\|127.0.0.1" > /dev/null; then
        SECURITY_ISSUES+=("Non-HTTPS URLs detected")
        ((issues_found++))
    fi
    
    if [ $issues_found -eq 0 ]; then
        test_pass "Dependencies appear secure"
    else
        test_fail "$issues_found dependency security issues"
    fi
}

test_oauth_security() {
    test_start "OAuth Security Configuration"
    
    local issues_found=0
    
    # Check for PKCE implementation
    if ! grep -r "code_challenge\|code_verifier" "$PROJECT_DIR/hooks/lib/oauth-handler.sh" 2>/dev/null > /dev/null; then
        SECURITY_ISSUES+=("PKCE not implemented (recommended for OAuth)")
        ((issues_found++))
    fi
    
    # Check for state parameter
    if ! grep -r "state=" "$PROJECT_DIR/hooks/lib/oauth-handler.sh" 2>/dev/null > /dev/null; then
        SECURITY_ISSUES+=("OAuth state parameter not used (CSRF protection)")
        ((issues_found++))
    fi
    
    # Check token storage encryption
    if [ -f "$PROJECT_DIR/hooks/lib/oauth-handler.sh" ]; then
        if ! grep -q "encrypt_data\|encrypt_file" "$PROJECT_DIR/hooks/lib/oauth-handler.sh"; then
            SECURITY_ISSUES+=("OAuth tokens may not be encrypted")
            ((issues_found++))
        fi
    fi
    
    if [ $issues_found -eq 0 ]; then
        test_pass "OAuth security properly configured"
    else
        test_fail "$issues_found OAuth security issues"
    fi
}

generate_security_report() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "                 SECURITY AUDIT REPORT                  "
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    if [ ${#SECURITY_ISSUES[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No security issues detected${NC}"
        echo ""
        echo "All security checks passed successfully!"
    else
        echo -e "${RED}⚠ ${#SECURITY_ISSUES[@]} security issues detected:${NC}"
        echo ""
        
        local i=1
        for issue in "${SECURITY_ISSUES[@]}"; do
            echo "$i. $issue"
            ((i++))
        done
        
        echo ""
        echo "Recommendations:"
        echo "1. Review and fix all file permission issues"
        echo "2. Remove or properly secure any exposed secrets"
        echo "3. Validate all user inputs before use"
        echo "4. Use HTTPS for all external connections"
        echo "5. Implement PKCE for OAuth flows"
        echo "6. Ensure all tokens are encrypted at rest"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════"
}

# Run all security tests
run_all_security_tests() {
    echo "Security Audit Tests"
    echo "==================="
    
    test_file_permissions
    test_secret_exposure
    test_command_injection
    test_log_security
    test_encryption_strength
    test_input_validation
    test_dependency_security
    test_oauth_security
    
    generate_security_report
    
    test_summary
    
    # Return failure if any security issues found
    if [ ${#SECURITY_ISSUES[@]} -gt 0 ]; then
        return 1
    fi
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_security_tests
fi