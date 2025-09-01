#!/bin/bash
# ABOUTME: OAuth management with automatic token refresh and health monitoring

# OAuth Manager for Gemini CLI
# Handles authentication, token refresh, and health monitoring

set -euo pipefail

# Configuration
OAUTH_CREDS_FILE="$HOME/.gemini/oauth_creds.json"
OAUTH_STATUS_CACHE="$HOME/.claude/gemini-oauth-status.json"
REFRESH_BUFFER=300  # Refresh if less than 5 minutes remaining
DEBUG="${DEBUG:-0}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

# Debug logging
debug_log() {
    [[ "$DEBUG" == "1" ]] && echo -e "${DIM}[OAuth] $1${NC}" >&2
}

# Check OAuth status
check_oauth_status() {
    local status="unknown"
    local expiry_time=0
    local time_remaining=0
    
    if [[ ! -f "$OAUTH_CREDS_FILE" ]]; then
        status="not_authenticated"
        debug_log "No OAuth credentials file found"
    else
        # Extract token expiry
        expiry_time=$(jq -r '.exp // 0' "$OAUTH_CREDS_FILE" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        time_remaining=$((expiry_time - current_time))
        
        if [[ "$time_remaining" -gt "$REFRESH_BUFFER" ]]; then
            status="valid"
            debug_log "Token valid for $(($time_remaining / 60)) minutes"
        elif [[ "$time_remaining" -gt 0 ]]; then
            status="expiring_soon"
            debug_log "Token expiring in $(($time_remaining / 60)) minutes"
        else
            status="expired"
            debug_log "Token expired $(( -$time_remaining / 60)) minutes ago"
        fi
    fi
    
    # Cache status
    mkdir -p "$(dirname "$OAUTH_STATUS_CACHE")"
    cat > "$OAUTH_STATUS_CACHE" <<EOF
{
    "status": "$status",
    "expiry": $expiry_time,
    "time_remaining": $time_remaining,
    "checked_at": $(date +%s)
}
EOF
    
    echo "$status"
}

# Refresh OAuth token
refresh_oauth_token() {
    debug_log "Attempting to refresh OAuth token..."
    
    # Gemini CLI auto-refreshes on API calls
    # Make a minimal API call to trigger refresh
    local refresh_output=$(gemini -p "test" -q "1" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        debug_log "Token refresh successful"
        
        # Verify new token
        local new_status=$(check_oauth_status)
        if [[ "$new_status" == "valid" ]]; then
            return 0
        else
            debug_log "Token refreshed but status is: $new_status"
            return 1
        fi
    else
        debug_log "Token refresh failed: $refresh_output"
        return 1
    fi
}

# Ensure authentication is valid
ensure_authenticated() {
    local status=$(check_oauth_status)
    
    case "$status" in
        "valid")
            debug_log "Authentication valid"
            return 0
            ;;
        "expiring_soon")
            debug_log "Token expiring soon, refreshing..."
            if refresh_oauth_token; then
                return 0
            else
                echo -e "${YELLOW}⚠️ Token refresh failed, may need manual re-authentication${NC}" >&2
                return 1
            fi
            ;;
        "expired")
            debug_log "Token expired, attempting refresh..."
            if refresh_oauth_token; then
                return 0
            else
                echo -e "${RED}❌ Token expired and refresh failed${NC}" >&2
                return 1
            fi
            ;;
        "not_authenticated")
            echo -e "${RED}❌ Gemini not authenticated. Run: gemini auth login${NC}" >&2
            return 1
            ;;
        *)
            debug_log "Unknown status: $status"
            return 1
            ;;
    esac
}

# Interactive OAuth setup
setup_oauth_interactive() {
    echo -e "${GREEN}🔐 Gemini OAuth Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The Gemini CLI requires OAuth authentication to access Google's AI models."
    echo "This is a one-time setup that provides free access to powerful language models."
    echo ""
    echo "Steps:"
    echo "  1. A browser will open for Google sign-in"
    echo "  2. Sign in with your Google account"
    echo "  3. Authorize the Gemini CLI application"
    echo "  4. Return to this terminal when complete"
    echo ""
    
    read -p "Press Enter to start OAuth setup... "
    
    echo ""
    echo "Opening browser for authentication..."
    
    # Run Gemini auth login
    if gemini auth login; then
        echo ""
        
        # Verify authentication
        if [[ -f "$OAUTH_CREDS_FILE" ]]; then
            echo -e "${GREEN}✅ OAuth setup successful!${NC}"
            
            # Test the connection
            echo "Testing Gemini connection..."
            if gemini -p "test" -q "Say OK" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Gemini connection verified!${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️ OAuth complete but test failed - you may need to retry${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ OAuth setup failed - credentials file not created${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ OAuth setup command failed${NC}"
        return 1
    fi
}

# Get OAuth status for display
get_oauth_info() {
    if [[ ! -f "$OAUTH_CREDS_FILE" ]]; then
        echo "Not authenticated"
        return
    fi
    
    local expiry=$(jq -r '.exp // 0' "$OAUTH_CREDS_FILE" 2>/dev/null)
    local current_time=$(date +%s)
    local time_remaining=$((expiry - current_time))
    
    if [[ "$time_remaining" -gt 0 ]]; then
        local minutes=$((time_remaining / 60))
        local hours=$((minutes / 60))
        
        if [[ "$hours" -gt 0 ]]; then
            echo "Valid for ${hours}h $((minutes % 60))m"
        else
            echo "Valid for ${minutes} minutes"
        fi
    else
        echo "Expired"
    fi
}

# Monitor OAuth health
monitor_oauth_health() {
    local check_interval="${1:-300}"  # Default 5 minutes
    
    echo "Starting OAuth health monitor (checking every ${check_interval}s)..."
    
    while true; do
        local status=$(check_oauth_status)
        local timestamp=$(date -Iseconds)
        
        case "$status" in
            "valid")
                debug_log "[$timestamp] OAuth healthy"
                ;;
            "expiring_soon")
                echo "[$timestamp] Token expiring soon, refreshing..."
                refresh_oauth_token
                ;;
            "expired")
                echo "[$timestamp] Token expired, attempting refresh..."
                if ! refresh_oauth_token; then
                    echo "[$timestamp] ERROR: Token refresh failed, manual intervention needed"
                fi
                ;;
            "not_authenticated")
                echo "[$timestamp] ERROR: Not authenticated"
                break
                ;;
        esac
        
        sleep "$check_interval"
    done
}

# Self-test
self_test() {
    echo "OAuth Manager Self-Test"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    
    echo -n "Checking OAuth status... "
    local status=$(check_oauth_status)
    echo "$status"
    
    echo -n "OAuth info: "
    get_oauth_info
    
    if [[ "$status" == "valid" ]] || [[ "$status" == "expiring_soon" ]]; then
        echo -n "Testing authentication... "
        if ensure_authenticated; then
            echo "✅ Passed"
        else
            echo "❌ Failed"
        fi
    fi
    
    echo ""
    echo "OAuth credentials: ${OAUTH_CREDS_FILE}"
    echo "Status cache: ${OAUTH_STATUS_CACHE}"
}

# Command-line interface
case "${1:-}" in
    check)
        check_oauth_status
        ;;
    refresh)
        refresh_oauth_token
        ;;
    ensure)
        ensure_authenticated
        ;;
    setup)
        setup_oauth_interactive
        ;;
    info)
        get_oauth_info
        ;;
    monitor)
        monitor_oauth_health "${2:-300}"
        ;;
    test)
        self_test
        ;;
    *)
        # When sourced, just provide functions
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            echo "Usage: $0 {check|refresh|ensure|setup|info|monitor|test}"
            exit 1
        fi
        ;;
esac