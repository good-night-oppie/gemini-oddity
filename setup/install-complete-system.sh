#!/bin/bash
# Claude-Gemini Bridge Complete System Installer
# Installs bridge, hooks, PR monitoring, and GitHub Actions

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DEFAULT_TARGET="$HOME/workspace/claude-gemini-bridge"
readonly TARGET_DIR="${1:-$DEFAULT_TARGET}"
readonly CLAUDE_SETTINGS_FILE="$HOME/.claude/settings.json"
readonly BACKUP_DIR="$HOME/.claude/backups"
readonly BACKUP_SUFFIX=$(date +%Y%m%d_%H%M%S)

# Installation flags
INSTALL_BRIDGE=true
INSTALL_HOOKS=true
INSTALL_PR_MONITOR=true
INSTALL_GITHUB_ACTIONS=true
CONFIGURE_SECRETS=false

# Display banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║     Claude-Gemini Bridge Complete System Installer        ║"
    echo "║                                                            ║"
    echo "║  🚀 Bridge + 🎯 PR Review + 🔄 CI Monitor + 🤖 Automation  ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Log function
log() {
    local level=$1
    shift
    case $level in
        info) echo -e "${GREEN}✅${NC} $*" ;;
        warn) echo -e "${YELLOW}⚠️${NC}  $*" ;;
        error) echo -e "${RED}❌${NC} $*" ;;
        step) echo -e "${BLUE}🔧${NC} $*" ;;
        success) echo -e "${GREEN}🎉${NC} $*" ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log step "Checking prerequisites..."
    
    local missing=()
    
    # Required tools
    for tool in git jq gh; do
        if ! command -v $tool &> /dev/null; then
            missing+=($tool)
        fi
    done
    
    # Optional but recommended
    for tool in claude gemini shellcheck; do
        if ! command -v $tool &> /dev/null; then
            log warn "$tool not found (optional but recommended)"
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Installation commands:"
        echo "  macOS: brew install ${missing[*]}"
        echo "  Ubuntu: sudo apt-get install ${missing[*]}"
        exit 1
    fi
    
    log info "All required tools found"
}

# Interactive setup
interactive_setup() {
    echo ""
    echo -e "${MAGENTA}=== Installation Options ===${NC}"
    echo ""
    
    # Installation directory
    echo -e "${CYAN}Where should the bridge be installed?${NC}"
    echo "  Current: $TARGET_DIR"
    read -p "Press Enter to accept or type new path: " custom_path
    if [ -n "$custom_path" ]; then
        TARGET_DIR="$custom_path"
    fi
    
    echo ""
    echo -e "${CYAN}Select components to install:${NC}"
    
    # Component selection
    read -p "1. Install Claude-Gemini Bridge? (Y/n): " install_bridge
    INSTALL_BRIDGE=${install_bridge:-Y}
    INSTALL_BRIDGE=${INSTALL_BRIDGE^^}
    
    read -p "2. Install PR Review Monitor? (Y/n): " install_pr
    INSTALL_PR_MONITOR=${install_pr:-Y}
    INSTALL_PR_MONITOR=${INSTALL_PR_MONITOR^^}
    
    read -p "3. Install CI/CD Monitoring? (Y/n): " install_ci
    INSTALL_HOOKS=${install_ci:-Y}
    INSTALL_HOOKS=${INSTALL_HOOKS^^}
    
    read -p "4. Install GitHub Actions workflows? (Y/n): " install_gh
    INSTALL_GITHUB_ACTIONS=${install_gh:-Y}
    INSTALL_GITHUB_ACTIONS=${INSTALL_GITHUB_ACTIONS^^}
    
    # GitHub configuration
    if [[ "$INSTALL_GITHUB_ACTIONS" == "Y" ]]; then
        echo ""
        echo -e "${CYAN}GitHub Configuration:${NC}"
        read -p "Configure GitHub secrets now? (y/N): " config_secrets
        CONFIGURE_SECRETS=${config_secrets:-N}
        CONFIGURE_SECRETS=${CONFIGURE_SECRETS^^}
        
        if [[ "$CONFIGURE_SECRETS" == "Y" ]]; then
            read -p "GitHub repository (owner/name): " GITHUB_REPO
            read -p "Use self-hosted runner? (y/N): " use_runner
            if [[ "${use_runner^^}" == "Y" ]]; then
                read -p "Runner name (default: ai-dev-runner-1): " RUNNER_NAME
                RUNNER_NAME=${RUNNER_NAME:-ai-dev-runner-1}
            else
                RUNNER_NAME="ubuntu-latest"
            fi
        fi
    fi
    
    # Delegation settings
    echo ""
    echo -e "${CYAN}Gemini Delegation Settings:${NC}"
    echo "Which tools should delegate to Gemini?"
    echo "  1. Read only"
    echo "  2. Task only"
    echo "  3. Read + Grep + Glob"
    echo "  4. All (Read|Grep|Glob|Task)"
    read -p "Selection (1-4, default: 4): " delegation_choice
    
    case ${delegation_choice:-4} in
        1) DELEGATION_TOOLS="Read" ;;
        2) DELEGATION_TOOLS="Task" ;;
        3) DELEGATION_TOOLS="Read|Grep|Glob" ;;
        *) DELEGATION_TOOLS="Read|Grep|Glob|Task" ;;
    esac
    
    # Confirmation
    echo ""
    echo -e "${YELLOW}=== Installation Summary ===${NC}"
    echo "  Target directory: $TARGET_DIR"
    echo "  Components:"
    [[ "$INSTALL_BRIDGE" == "Y" ]] && echo "    ✓ Claude-Gemini Bridge"
    [[ "$INSTALL_PR_MONITOR" == "Y" ]] && echo "    ✓ PR Review Monitor"
    [[ "$INSTALL_HOOKS" == "Y" ]] && echo "    ✓ CI/CD Monitoring"
    [[ "$INSTALL_GITHUB_ACTIONS" == "Y" ]] && echo "    ✓ GitHub Actions"
    echo "  Delegation tools: $DELEGATION_TOOLS"
    echo ""
    read -p "Continue with installation? (Y/n): " confirm
    if [[ "${confirm^^}" == "N" ]]; then
        log warn "Installation cancelled"
        exit 0
    fi
}

# Backup existing configuration
backup_configuration() {
    log step "Backing up existing configuration..."
    
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$CLAUDE_SETTINGS_FILE" ]; then
        cp "$CLAUDE_SETTINGS_FILE" "$BACKUP_DIR/settings.json.$BACKUP_SUFFIX"
        log info "Claude settings backed up"
    fi
    
    if [ -d "$TARGET_DIR" ]; then
        tar -czf "$BACKUP_DIR/bridge-backup-$BACKUP_SUFFIX.tar.gz" "$TARGET_DIR" 2>/dev/null || true
        log info "Existing bridge backed up"
    fi
}

# Install bridge files
install_bridge_files() {
    if [[ "$INSTALL_BRIDGE" != "Y" ]]; then
        return 0
    fi
    
    log step "Installing Claude-Gemini Bridge..."
    
    # Create target directory
    mkdir -p "$TARGET_DIR"
    
    # Copy core directories
    for dir in hooks test docs scripts; do
        if [ -d "$SOURCE_DIR/$dir" ]; then
            cp -r "$SOURCE_DIR/$dir" "$TARGET_DIR/" 2>/dev/null || true
        fi
    done
    
    # Copy essential files
    for file in README.md LICENSE project-uninstall.sh; do
        if [ -f "$SOURCE_DIR/$file" ]; then
            cp "$SOURCE_DIR/$file" "$TARGET_DIR/" 2>/dev/null || true
        fi
    done
    
    # Create working directories
    mkdir -p "$TARGET_DIR"/{cache/gemini,logs/debug,debug/captured}
    mkdir -p "$TARGET_DIR"/cache/{pr-monitor,pr-state,automation-state}
    
    # Make scripts executable
    find "$TARGET_DIR" -name "*.sh" -exec chmod +x {} \;
    
    log info "Bridge files installed"
}

# Configure Claude hooks
configure_claude_hooks() {
    log step "Configuring Claude hooks..."
    
    # Create settings if not exists
    if [ ! -f "$CLAUDE_SETTINGS_FILE" ]; then
        mkdir -p "$(dirname "$CLAUDE_SETTINGS_FILE")"
        echo '{"hooks": {}}' > "$CLAUDE_SETTINGS_FILE"
    fi
    
    # Update hooks configuration
    local current_config=$(cat "$CLAUDE_SETTINGS_FILE")
    local hook_command="$TARGET_DIR/hooks/gemini-bridge.sh"
    local pr_monitor_command="$TARGET_DIR/hooks/pr-review/pr-monitor.sh"
    local unified_command="$TARGET_DIR/hooks/unified-automation.sh"
    
    local updated_config=$(echo "$current_config" | jq \
        --arg hook_cmd "$hook_command" \
        --arg pr_cmd "$pr_monitor_command" \
        --arg unified_cmd "$unified_command" \
        --arg tools "$DELEGATION_TOOLS" '
        # Ensure hooks object exists
        .hooks = (.hooks // {}) |
        
        # Configure PreToolUse hooks for Gemini delegation
        .hooks.PreToolUse = [
            {
                "matcher": $tools,
                "hooks": [
                    {
                        "type": "command",
                        "command": $hook_cmd,
                        "description": "Delegate large tasks to Gemini"
                    }
                ]
            }
        ] |
        
        # Configure PostToolUse hooks for PR monitoring
        .hooks.PostToolUse = [
            {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        "command": ($unified_cmd + " \"${CLAUDE_TOOL_INPUT}\""),
                        "conditions": {
                            "patterns": [
                                "git push",
                                "gh pr create",
                                "gh pr comment.*@claude"
                            ]
                        },
                        "description": "Unified automation for PR and CI"
                    }
                ]
            }
        ]
    ')
    
    echo "$updated_config" > "$CLAUDE_SETTINGS_FILE"
    log info "Claude hooks configured"
}

# Install GitHub Actions
install_github_actions() {
    if [[ "$INSTALL_GITHUB_ACTIONS" != "Y" ]]; then
        return 0
    fi
    
    log step "Installing GitHub Actions workflows..."
    
    # Detect if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log warn "Not in a git repository. Skipping GitHub Actions installation."
        log warn "Copy workflows manually from: $SOURCE_DIR/.github/workflows/"
        return 0
    fi
    
    # Create workflows directory
    mkdir -p .github/workflows
    
    # Copy workflow file
    if [ -f "$SOURCE_DIR/.github/workflows/claude-pr-review.yml" ]; then
        cp "$SOURCE_DIR/.github/workflows/claude-pr-review.yml" .github/workflows/
        
        # Update runner if specified
        if [ -n "${RUNNER_NAME:-}" ]; then
            sed -i.bak "s/ai-dev-runner-1/$RUNNER_NAME/g" .github/workflows/claude-pr-review.yml
            rm .github/workflows/claude-pr-review.yml.bak
        fi
        
        log info "GitHub Actions workflow installed"
    fi
}

# Configure GitHub secrets
configure_github_secrets() {
    if [[ "$CONFIGURE_SECRETS" != "Y" ]]; then
        return 0
    fi
    
    log step "Configuring GitHub secrets..."
    
    echo ""
    echo "Please provide the following secrets:"
    echo "(Press Enter to skip any secret)"
    echo ""
    
    read -s -p "CLAUDE_CODE_OAUTH_TOKEN: " oauth_token
    echo ""
    read -s -p "CLAUDE_ACCESS_TOKEN: " access_token
    echo ""
    read -s -p "CLAUDE_REFRESH_TOKEN: " refresh_token
    echo ""
    read -s -p "GEMINI_API_KEY: " gemini_key
    echo ""
    
    # Set secrets using gh CLI
    if [ -n "$oauth_token" ]; then
        echo "$oauth_token" | gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo "$GITHUB_REPO"
    fi
    if [ -n "$access_token" ]; then
        echo "$access_token" | gh secret set CLAUDE_ACCESS_TOKEN --repo "$GITHUB_REPO"
    fi
    if [ -n "$refresh_token" ]; then
        echo "$refresh_token" | gh secret set CLAUDE_REFRESH_TOKEN --repo "$GITHUB_REPO"
    fi
    if [ -n "$gemini_key" ]; then
        echo "$gemini_key" | gh secret set GEMINI_API_KEY --repo "$GITHUB_REPO"
    fi
    
    log info "GitHub secrets configured"
}

# Create helper scripts
create_helper_scripts() {
    log step "Creating helper scripts..."
    
    # Create activation script
    cat > "$TARGET_DIR/activate.sh" << 'EOF'
#!/bin/bash
# Activate Claude-Gemini Bridge helpers

BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Aliases
alias cgb-monitor="$BRIDGE_DIR/hooks/pr-review/pr-monitor.sh"
alias cgb-test="$BRIDGE_DIR/test/test-runner.sh"
alias cgb-logs="tail -f $BRIDGE_DIR/logs/debug/\$(date +%Y%m%d).log"
alias cgb-cache-clear="rm -rf $BRIDGE_DIR/cache/gemini/*"
alias cgb-status="$BRIDGE_DIR/hooks/pr-review/pr-monitor.sh status"

# Functions
cgb-help() {
    echo "Claude-Gemini Bridge Commands:"
    echo "  cgb-monitor <pr> [complexity] - Monitor PR review"
    echo "  cgb-status                    - Show active monitors"
    echo "  cgb-test                      - Run tests"
    echo "  cgb-logs                      - View logs"
    echo "  cgb-cache-clear              - Clear cache"
}

echo "Claude-Gemini Bridge activated. Type 'cgb-help' for commands."
EOF
    
    chmod +x "$TARGET_DIR/activate.sh"
    log info "Helper scripts created"
}

# Run tests
run_tests() {
    log step "Running installation tests..."
    
    # Test bridge hook
    if [ -f "$TARGET_DIR/hooks/gemini-bridge.sh" ]; then
        local test_json='{"tool_name":"Read","tool_input":{"file_path":"test.txt"}}'
        if echo "$test_json" | "$TARGET_DIR/hooks/gemini-bridge.sh" 2>/dev/null | jq empty 2>/dev/null; then
            log info "Bridge hook test passed"
        else
            log warn "Bridge hook test failed (may be normal without Gemini API key)"
        fi
    fi
    
    # Test PR monitor
    if [ -f "$TARGET_DIR/hooks/pr-review/pr-monitor.sh" ]; then
        if "$TARGET_DIR/hooks/pr-review/pr-monitor.sh" status &>/dev/null; then
            log info "PR monitor test passed"
        fi
    fi
}

# Display summary
show_summary() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}          Installation Complete! 🎉                          ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}📁 Installation Details:${NC}"
    echo "   Bridge location: $TARGET_DIR"
    echo "   Claude settings: $CLAUDE_SETTINGS_FILE"
    echo "   Backup location: $BACKUP_DIR"
    echo ""
    
    echo -e "${CYAN}✨ Features Installed:${NC}"
    [[ "$INSTALL_BRIDGE" == "Y" ]] && echo "   ✓ Claude-Gemini Bridge with $DELEGATION_TOOLS delegation"
    [[ "$INSTALL_PR_MONITOR" == "Y" ]] && echo "   ✓ PR Review Monitor with debate protocol"
    [[ "$INSTALL_HOOKS" == "Y" ]] && echo "   ✓ CI/CD Monitoring with auto-fix"
    [[ "$INSTALL_GITHUB_ACTIONS" == "Y" ]] && echo "   ✓ GitHub Actions workflows"
    echo ""
    
    echo -e "${CYAN}🚀 Quick Start:${NC}"
    echo "   1. Restart Claude Code (required for hooks)"
    echo "   2. Activate helpers: source $TARGET_DIR/activate.sh"
    echo "   3. Test installation: cgb-test"
    echo ""
    
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo "   Main README: $TARGET_DIR/README.md"
    echo "   Advanced Hooks: $TARGET_DIR/docs/ADVANCED_HOOKS.md"
    echo "   Troubleshooting: $TARGET_DIR/docs/TROUBLESHOOTING.md"
    echo ""
    
    echo -e "${CYAN}💡 Next Steps:${NC}"
    echo "   • Create a PR: git push && gh pr create"
    echo "   • Request review: gh pr comment <pr> --body '@claude please review'"
    echo "   • Monitor status: cgb-status"
    echo ""
    
    if [[ "$INSTALL_GITHUB_ACTIONS" == "Y" ]] && [[ "$CONFIGURE_SECRETS" != "Y" ]]; then
        echo -e "${YELLOW}⚠️  Don't forget to configure GitHub secrets:${NC}"
        echo "   gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner/repo>"
        echo "   gh secret set GEMINI_API_KEY --repo <owner/repo>"
        echo ""
    fi
    
    echo -e "${GREEN}Happy coding with Claude-Gemini Bridge! 🤖${NC}"
}

# Main installation flow
main() {
    show_banner
    check_prerequisites
    interactive_setup
    
    echo ""
    log step "Starting installation..."
    echo ""
    
    backup_configuration
    install_bridge_files
    configure_claude_hooks
    install_github_actions
    configure_github_secrets
    create_helper_scripts
    run_tests
    
    show_summary
}

# Run installation
main "$@"