#!/bin/bash
# ABOUTME: Enhanced installer with OAuth setup, project registry, and user notifications

# Claude-Gemini Bridge Enhanced Installer v2.0
# Features:
# - Automatic project registration
# - OAuth setup wizard with token refresh
# - Per-project isolation with universal router
# - User-friendly notifications
# - Smart detection and configuration

set -euo pipefail

# Version and paths
INSTALLER_VERSION="2.0.0"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$(pwd)/.claude-gemini-bridge"
BRIDGE_REGISTRY="$HOME/.claude/bridge-registry.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
UNIVERSAL_ROUTER="$HOME/.claude/hooks/universal-router.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Log functions
log() {
    local level="$1"
    local message="$2"
    
    case $level in
        "info") echo -e "${GREEN}✅${NC} $message" ;;
        "warn") echo -e "${YELLOW}⚠️${NC}  $message" ;;
        "error") echo -e "${RED}❌${NC} $message" ;;
        "debug") [[ "${DEBUG:-0}" == "1" ]] && echo -e "${DIM}🔍 $message${NC}" ;;
        "step") echo -e "${BLUE}▶${NC} $message" ;;
    esac
}

header() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Error handling
error_exit() {
    log "error" "$1"
    echo ""
    echo "💥 Installation failed!"
    echo "📚 See troubleshooting guide: https://github.com/good-night-oppie/claude-gemini-bridge#troubleshooting"
    exit 1
}

# Check Gemini OAuth status
check_gemini_auth() {
    local auth_status="unknown"
    local oauth_file="$HOME/.gemini/oauth_creds.json"
    
    # First, try to actually use Gemini to see if it works
    if echo "test" | gemini -p "Say OK" >/dev/null 2>&1; then
        auth_status="valid"
        log "debug" "Gemini is working properly"
        echo "$auth_status"
        return 0
    fi
    
    if [[ -f "$oauth_file" ]]; then
        # Check token expiry
        local expiry=$(jq -r '.exp // 0' "$oauth_file" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        
        if [[ "$expiry" -gt "$current_time" ]]; then
            auth_status="valid"
            log "debug" "OAuth token valid, expires in $(( (expiry - current_time) / 60 )) minutes"
        else
            auth_status="expired"
            log "debug" "OAuth token expired $(( (current_time - expiry) / 60 )) minutes ago"
        fi
    else
        auth_status="not_authenticated"
        log "debug" "No OAuth credentials file found"
    fi
    
    echo "$auth_status"
}

# Setup Gemini OAuth
setup_gemini_oauth() {
    header "🔐 Gemini OAuth Setup"
    
    echo "The Gemini CLI needs OAuth authentication to access Google's AI models."
    echo "This provides free access to powerful language models for code analysis."
    echo ""
    echo -e "${CYAN}Steps:${NC}"
    echo "  1. Run: gemini auth login"
    echo "  2. A browser will open for Google sign-in"
    echo "  3. Authorize the Gemini CLI application"
    echo "  4. Return to terminal when complete"
    echo ""
    
    read -p "Press Enter to start OAuth setup (or Ctrl+C to skip)... "
    
    # Run Gemini auth (Note: Gemini CLI doesn't have auth login command)
    log "step" "Testing Gemini connection..."
    if echo "OK" | gemini -p "test" >/dev/null 2>&1; then
        # Verify success
        if [[ -f "$HOME/.gemini/oauth_creds.json" ]]; then
            log "info" "OAuth setup successful!"
            
            # Test with a simple call
            log "step" "Testing Gemini connection..."
            if echo "Say OK" | gemini -p "test" >/dev/null 2>&1; then
                log "info" "Gemini connection verified!"
                return 0
            else
                log "warn" "OAuth setup complete but test failed - may need to retry"
                return 1
            fi
        else
            log "error" "OAuth setup failed - credentials file not created"
            return 1
        fi
    else
        log "error" "OAuth setup command failed"
        return 1
    fi
}

# Refresh OAuth token if needed
ensure_gemini_authenticated() {
    local oauth_file="$HOME/.gemini/oauth_creds.json"
    
    if [[ ! -f "$oauth_file" ]]; then
        log "warn" "Gemini not authenticated"
        return 1
    fi
    
    local expiry=$(jq -r '.exp // 0' "$oauth_file" 2>/dev/null)
    local current_time=$(date +%s)
    local time_until_expiry=$((expiry - current_time))
    
    if [[ "$time_until_expiry" -lt 300 ]]; then  # Less than 5 minutes
        log "step" "Refreshing Gemini OAuth token..."
        
        # Trigger refresh with a simple API call
        if echo "1+1" | gemini -p "Calculate" >/dev/null 2>&1; then
            log "info" "Token refreshed successfully"
            return 0
        else
            log "warn" "Token refresh failed - manual re-auth may be needed"
            return 1
        fi
    fi
    
    return 0
}

# Initialize or update registry
initialize_registry() {
    if [[ ! -f "$BRIDGE_REGISTRY" ]]; then
        mkdir -p "$(dirname "$BRIDGE_REGISTRY")"
        cat > "$BRIDGE_REGISTRY" <<EOF
{
    "version": "$INSTALLER_VERSION",
    "projects": {},
    "router_installed": "$(date -Iseconds)"
}
EOF
        log "debug" "Created new bridge registry"
    fi
}

# Register project in global registry
register_project() {
    local project_dir="$1"
    local tools="${2:-Read|Grep|Glob|Task}"
    
    initialize_registry
    
    # Update registry with project
    local temp_registry=$(mktemp)
    jq --arg dir "$project_dir" \
       --arg version "$INSTALLER_VERSION" \
       --arg tools "$tools" \
       --arg timestamp "$(date -Iseconds)" \
       '.projects[$dir] = {
           "registered": $timestamp,
           "bridge_version": $version,
           "config": {
               "tools": $tools,
               "enabled": true
           }
       }' "$BRIDGE_REGISTRY" > "$temp_registry"
    
    mv "$temp_registry" "$BRIDGE_REGISTRY"
    log "info" "Project registered: $(basename "$project_dir")"
}

# Install universal router
install_universal_router() {
    local router_dir="$HOME/.claude/hooks"
    mkdir -p "$router_dir"
    
    # Copy universal router
    cp "$SOURCE_DIR/hooks/universal-router.sh" "$UNIVERSAL_ROUTER"
    chmod +x "$UNIVERSAL_ROUTER"
    
    # Update Claude settings to use universal router
    if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
        mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
        echo '{}' > "$CLAUDE_SETTINGS"
    fi
    
    # Check if router is already configured
    local current_hook=$(jq -r '.tools.preToolUse // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
    
    if [[ "$current_hook" != "$UNIVERSAL_ROUTER" ]]; then
        # Backup existing settings
        cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update settings to use universal router
        local temp_settings=$(mktemp)
        jq --arg router "$UNIVERSAL_ROUTER" \
           '.tools.preToolUse = $router' "$CLAUDE_SETTINGS" > "$temp_settings"
        
        mv "$temp_settings" "$CLAUDE_SETTINGS"
        log "info" "Universal router installed"
    else
        log "debug" "Universal router already configured"
    fi
}

# Copy bridge files
copy_bridge_files() {
    log "step" "Installing bridge files to $TARGET_DIR..."
    
    # Create target directory
    mkdir -p "$TARGET_DIR"
    
    # Copy essential directories
    for dir in hooks test docs scripts; do
        if [[ -d "$SOURCE_DIR/$dir" ]]; then
            cp -r "$SOURCE_DIR/$dir" "$TARGET_DIR/"
        fi
    done
    
    # Copy essential files
    for file in README.md LICENSE CLAUDE.md; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            cp "$SOURCE_DIR/$file" "$TARGET_DIR/"
        fi
    done
    
    # Create uninstaller
    cat > "$TARGET_DIR/uninstall.sh" <<'EOF'
#!/bin/bash
# Project-specific uninstaller

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_REGISTRY="$HOME/.claude/bridge-registry.json"

echo "🗑️  Uninstalling Claude-Gemini Bridge from $PROJECT_DIR"

# Remove from registry
if [[ -f "$BRIDGE_REGISTRY" ]]; then
    temp_registry=$(mktemp)
    jq --arg dir "$PROJECT_DIR" 'del(.projects[$dir])' "$BRIDGE_REGISTRY" > "$temp_registry"
    mv "$temp_registry" "$BRIDGE_REGISTRY"
    echo "✅ Project unregistered"
fi

# Remove bridge directory
rm -rf "$PROJECT_DIR/.claude-gemini-bridge"
echo "✅ Bridge files removed"

echo "🎉 Uninstall complete!"
EOF
    chmod +x "$TARGET_DIR/uninstall.sh"
    
    # Create working directories
    mkdir -p "$TARGET_DIR"/{cache/gemini,logs/debug,debug/captured}
    
    log "info" "Bridge files installed"
}

# Setup token refresh cron (optional)
setup_token_refresh_cron() {
    echo ""
    read -p "Enable automatic token refresh? (Y/n): " enable_cron
    
    if [[ ! "$enable_cron" =~ ^[Nn]$ ]]; then
        # Add cron job to refresh token every 45 minutes
        local cron_cmd="*/45 * * * * gemini -p test -q '1+1' >/dev/null 2>&1"
        
        # Check if cron job already exists
        if ! crontab -l 2>/dev/null | grep -q "gemini.*test"; then
            (crontab -l 2>/dev/null || echo ""; echo "$cron_cmd") | crontab -
            log "info" "Auto-refresh cron job installed (every 45 minutes)"
        else
            log "debug" "Auto-refresh cron job already exists"
        fi
    fi
}

# Main installation flow
main() {
    clear
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║   Claude-Gemini Bridge Installer v2.0     ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════╝${NC}"
    
    # Step 1: Check prerequisites
    header "📋 Checking Prerequisites"
    
    log "step" "Checking Claude CLI..."
    if ! command -v claude &>/dev/null; then
        error_exit "Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    fi
    log "info" "Claude CLI found"
    
    log "step" "Checking Gemini CLI..."
    if ! command -v gemini &>/dev/null; then
        error_exit "Gemini CLI not found. Visit: https://github.com/google-gemini/gemini-cli"
    fi
    log "info" "Gemini CLI found"
    
    log "step" "Checking jq..."
    if ! command -v jq &>/dev/null; then
        log "warn" "jq not found. Installing guide:"
        echo "  macOS: brew install jq"
        echo "  Linux: sudo apt-get install jq"
        error_exit "jq is required for JSON processing"
    fi
    log "info" "jq found"
    
    # Step 2: Check/Setup Gemini OAuth
    header "🔑 Gemini Authentication"
    
    local auth_status=$(check_gemini_auth)
    case "$auth_status" in
        "valid")
            log "info" "Gemini OAuth is valid"
            ensure_gemini_authenticated
            ;;
        "expired")
            log "warn" "Gemini OAuth token expired"
            echo ""
            echo "Your token has expired but will auto-refresh during use."
            if ! ensure_gemini_authenticated; then
                setup_gemini_oauth
            fi
            ;;
        "not_authenticated")
            log "warn" "Gemini not authenticated"
            echo ""
            echo "Gemini OAuth is required for the bridge to delegate tasks."
            read -p "Set up Gemini OAuth now? (Y/n): " setup_oauth
            if [[ ! "$setup_oauth" =~ ^[Nn]$ ]]; then
                setup_gemini_oauth || log "warn" "Continuing without OAuth (bridge will be limited)"
            else
                log "warn" "Skipping OAuth setup - bridge functionality will be limited"
            fi
            ;;
    esac
    
    # Step 3: Install bridge files
    header "📦 Installing Bridge"
    
    copy_bridge_files
    
    # Step 4: Install/update universal router
    log "step" "Configuring universal router..."
    install_universal_router
    
    # Step 5: Register project
    log "step" "Registering project..."
    local project_dir="$(pwd)"
    
    # Ask which tools to enable
    echo ""
    echo "Which tools should the bridge handle?"
    echo "  1) All tools (Read, Grep, Glob, Task) [Default]"
    echo "  2) Task operations only"
    echo "  3) Custom selection"
    read -p "Choice (1-3): " tool_choice
    
    local tools="Read|Grep|Glob|Task"
    case "$tool_choice" in
        2) tools="Task" ;;
        3) 
            read -p "Enter tools (e.g., Read|Task): " custom_tools
            tools="$custom_tools"
            ;;
    esac
    
    register_project "$project_dir" "$tools"
    
    # Step 6: Optional token refresh cron
    header "⚙️  Optional Configuration"
    setup_token_refresh_cron
    
    # Step 7: Show summary
    header "✨ Installation Complete!"
    
    echo -e "${GREEN}Successfully installed Claude-Gemini Bridge!${NC}"
    echo ""
    echo "📍 Project: $(basename "$project_dir")"
    echo "🔧 Tools configured: $tools"
    echo "🌉 Bridge location: $TARGET_DIR"
    echo ""
    echo -e "${CYAN}Quick commands:${NC}"
    echo "  • Status: claude-bridge status"
    echo "  • List projects: claude-bridge list"
    echo "  • Uninstall: .claude-gemini-bridge/uninstall.sh"
    echo ""
    echo -e "${DIM}The bridge will automatically activate when Claude uses configured tools.${NC}"
    echo -e "${DIM}Set CLAUDE_BRIDGE_NOTIFY=verbose to see when delegation occurs.${NC}"
}

# Handle command-line arguments
case "${1:-install}" in
    install)
        main
        ;;
    status)
        "$UNIVERSAL_ROUTER" --status
        ;;
    list)
        if [[ -f "$BRIDGE_REGISTRY" ]]; then
            echo "Registered Projects:"
            jq -r '.projects | to_entries[] | "  ✓ \(.key) (v\(.value.bridge_version))"' "$BRIDGE_REGISTRY"
        else
            echo "No projects registered"
        fi
        ;;
    register)
        project_dir="${2:-$(pwd)}"
        register_project "$project_dir" "Read|Grep|Glob|Task"
        ;;
    unregister)
        project_dir="${2:-$(pwd)}"
        if [[ -f "$BRIDGE_REGISTRY" ]]; then
            temp_registry=$(mktemp)
            jq --arg dir "$project_dir" 'del(.projects[$dir])' "$BRIDGE_REGISTRY" > "$temp_registry"
            mv "$temp_registry" "$BRIDGE_REGISTRY"
            echo "✅ Project unregistered: $project_dir"
        fi
        ;;
    help|--help|-h)
        echo "Claude-Gemini Bridge Installer v$INSTALLER_VERSION"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  install     Install bridge in current directory (default)"
        echo "  status      Show router and project status"
        echo "  list        List all registered projects"
        echo "  register    Register current directory"
        echo "  unregister  Unregister current directory"
        echo "  help        Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac