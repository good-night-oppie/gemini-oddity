#!/bin/bash
# ABOUTME: Per-project uninstaller for Claude-Gemini Bridge

echo "🗑️  Claude-Gemini Bridge Uninstaller"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Global variables
BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SETTINGS_FILE="$HOME/.claude/settings.json"

# Log function
log() {
    local level="$1"
    local message="$2"
    
    case $level in
        "info") echo -e "${GREEN}✅${NC} $message" ;;
        "warn") echo -e "${YELLOW}⚠️${NC}  $message" ;;
        "error") echo -e "${RED}❌${NC} $message" ;;
    esac
}

# Remove hooks from Claude settings
remove_hooks() {
    log "info" "Removing Claude-Gemini Bridge hooks..."
    
    if [ ! -f "$CLAUDE_SETTINGS_FILE" ]; then
        log "warn" "Claude settings file not found: $CLAUDE_SETTINGS_FILE"
        return 0
    fi
    
    # Check if our hook exists
    local hook_path="$BRIDGE_DIR/hooks/gemini-bridge.sh"
    if ! grep -q "$hook_path" "$CLAUDE_SETTINGS_FILE" 2>/dev/null; then
        log "info" "No hooks found for this installation"
        return 0
    fi
    
    # Backup settings
    cp "$CLAUDE_SETTINGS_FILE" "${CLAUDE_SETTINGS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    log "info" "Settings backed up"
    
    # Remove hooks for this specific installation
    local cleaned_config=$(jq --arg path "$hook_path" '
        .hooks.PreToolUse = (.hooks.PreToolUse // []) | 
        .hooks.PreToolUse |= map(
            select(.hooks[]?.command != $path)
        ) |
        if (.hooks.PreToolUse | length) == 0 then 
            del(.hooks.PreToolUse) 
        else . end |
        if (.hooks | length) == 0 then 
            del(.hooks) 
        else . end
    ' "$CLAUDE_SETTINGS_FILE" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$cleaned_config" ]; then
        echo "$cleaned_config" > "$CLAUDE_SETTINGS_FILE"
        log "info" "Hooks removed from Claude settings"
    else
        log "error" "Failed to remove hooks automatically"
        echo "Please manually edit: $CLAUDE_SETTINGS_FILE"
    fi
}

# Remove bridge directory
remove_directory() {
    echo ""
    echo "Do you want to remove the bridge directory and all its data?"
    echo "Directory: $BRIDGE_DIR"
    read -p "Remove directory? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$BRIDGE_DIR"
        log "info" "Bridge directory removed"
    else
        log "info" "Bridge directory preserved"
    fi
}

# Main uninstall
main() {
    echo "This will remove the Claude-Gemini Bridge from this project."
    echo "Project directory: $(dirname "$BRIDGE_DIR")"
    echo ""
    read -p "Continue with uninstallation? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "info" "Uninstallation cancelled"
        exit 0
    fi
    
    echo ""
    
    # Remove hooks and optionally directory
    remove_hooks
    
    echo ""
    echo "✅ Hooks removed successfully!"
    echo ""
    echo "📚 Next steps:"
    echo "   1. RESTART Claude Code to apply changes"
    
    # Ask about directory removal
    remove_directory
    
    echo ""
    echo "🎉 Uninstallation complete!"
}

# Execute
main "$@"