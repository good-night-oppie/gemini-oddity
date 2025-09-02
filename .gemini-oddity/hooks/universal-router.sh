#!/bin/bash
# ABOUTME: Universal router that delegates to project-specific Gemini Oddity installations

# Universal Router for Gemini Oddity
# Routes tool calls to appropriate project-specific bridge installations
# Maintains a registry of installed projects and their configurations

set -euo pipefail

# Configuration
BRIDGE_REGISTRY="$HOME/.claude/bridge-registry.json"
BRIDGE_STATUS_LOG="$HOME/.claude/bridge-status.log"
ROUTER_VERSION="2.0.0"

# Notification levels
export GEMINI_ODDITY_NOTIFY="${GEMINI_ODDITY_NOTIFY:-subtle}"

# Colors for notifications
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

# Notification function
notify_user() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    # Always log to status file
    echo "$timestamp [$level] $message" >> "$BRIDGE_STATUS_LOG"
    
    case "$GEMINI_ODDITY_NOTIFY" in
        quiet)
            # Only log to file, no terminal output
            ;;
        subtle)
            # Brief indicator to stderr
            if [[ "$level" == "DELEGATE" ]]; then
                echo -e "${DIM}🌉${NC}" >&2
            elif [[ "$level" == "ERROR" ]]; then
                echo -e "${RED}⚠️ Bridge: $message${NC}" >&2
            fi
            ;;
        verbose)
            # Full message to stderr
            case "$level" in
                ACTIVE) echo -e "${GREEN}🌉 Bridge: $message${NC}" >&2 ;;
                DELEGATE) echo -e "${BLUE}🌉 Bridge: $message${NC}" >&2 ;;
                SUCCESS) echo -e "${GREEN}🌉 Bridge: $message${NC}" >&2 ;;
                ERROR) echo -e "${RED}🌉 Bridge: $message${NC}" >&2 ;;
                SKIP) echo -e "${DIM}🌉 Bridge: $message${NC}" >&2 ;;
                *) echo -e "🌉 Bridge: $message" >&2 ;;
            esac
            ;;
        debug)
            # Everything with debug info
            echo -e "${DIM}🌉 [DEBUG][$level] $message${NC}" >&2
            ;;
    esac
}

# Initialize registry if it doesn't exist
initialize_registry() {
    if [[ ! -f "$BRIDGE_REGISTRY" ]]; then
        mkdir -p "$(dirname "$BRIDGE_REGISTRY")"
        cat > "$BRIDGE_REGISTRY" <<EOF
{
    "version": "$ROUTER_VERSION",
    "projects": {},
    "router_installed": "$(date -Iseconds)"
}
EOF
        notify_user "INFO" "Initialized bridge registry"
    fi
}

# Extract working directory from tool call
extract_working_directory() {
    local tool_call="$1"
    
    # Try to extract from file paths in the tool call
    local working_dir=""
    
    # Look for absolute paths in the JSON
    if echo "$tool_call" | grep -q '"file_path"'; then
        working_dir=$(echo "$tool_call" | jq -r '.file_path // empty' 2>/dev/null | xargs dirname 2>/dev/null || true)
    elif echo "$tool_call" | grep -q '"path"'; then
        working_dir=$(echo "$tool_call" | jq -r '.path // empty' 2>/dev/null || true)
    fi
    
    # If no path found, try to get from environment or PWD
    if [[ -z "$working_dir" ]]; then
        working_dir="${CLAUDE_WORKING_DIR:-$(pwd)}"
    fi
    
    # Resolve to absolute path
    if [[ -n "$working_dir" ]] && [[ -d "$working_dir" ]]; then
        working_dir=$(cd "$working_dir" && pwd)
    fi
    
    echo "$working_dir"
}

# Find project root from working directory
find_project_root() {
    local dir="$1"
    
    # Walk up directory tree looking for project markers
    while [[ "$dir" != "/" ]]; do
        # Check for .gemini-oddity directory
        if [[ -d "$dir/.gemini-oddity" ]]; then
            echo "$dir"
            return 0
        fi
        
        # Check for common project root markers
        if [[ -f "$dir/.git/config" ]] || [[ -f "$dir/package.json" ]] || [[ -f "$dir/go.mod" ]]; then
            # Check if this project is registered
            if jq -e ".projects[\"$dir\"]" "$BRIDGE_REGISTRY" >/dev/null 2>&1; then
                echo "$dir"
                return 0
            fi
        fi
        
        # Move up one directory
        dir=$(dirname "$dir")
    done
    
    return 1
}

# Check if project is registered and enabled
is_project_registered() {
    local project_dir="$1"
    
    if [[ ! -f "$BRIDGE_REGISTRY" ]]; then
        return 1
    fi
    
    # Check if project exists in registry and is enabled
    local enabled=$(jq -r ".projects[\"$project_dir\"].config.enabled // false" "$BRIDGE_REGISTRY" 2>/dev/null)
    
    if [[ "$enabled" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Route to project-specific bridge
route_to_project_bridge() {
    local project_dir="$1"
    local tool_name="$2"
    local tool_args="$3"
    
    local bridge_script="$project_dir/.gemini-oddity/hooks/gemini-bridge.sh"
    
    if [[ ! -f "$bridge_script" ]]; then
        notify_user "ERROR" "Bridge script not found at $bridge_script"
        echo '{"action": "continue"}'
        return 1
    fi
    
    # Get project configuration
    local project_config=$(jq -r ".projects[\"$project_dir\"]" "$BRIDGE_REGISTRY" 2>/dev/null)
    local configured_tools=$(echo "$project_config" | jq -r '.config.tools // "Read|Grep|Glob|Task"' 2>/dev/null)
    
    # Check if this tool is configured for delegation
    if ! echo "$configured_tools" | grep -q "$tool_name"; then
        notify_user "SKIP" "Tool $tool_name not configured for delegation in this project"
        echo '{"action": "continue"}'
        return 0
    fi
    
    # Log delegation
    notify_user "DELEGATE" "Routing $tool_name to project: $(basename "$project_dir")"
    
    # Execute project-specific bridge
    export GEMINI_ODDITY_PROJECT_ROOT="$project_dir"
    bash "$bridge_script"
}

# Main routing logic
main() {
    # Initialize if needed
    initialize_registry
    
    # Read tool call from stdin
    local tool_call=$(cat)
    
    # Extract tool name
    local tool_name=$(echo "$tool_call" | jq -r '.tool // empty' 2>/dev/null)
    
    if [[ -z "$tool_name" ]]; then
        notify_user "ERROR" "Could not extract tool name from input"
        echo '{"action": "continue"}'
        exit 0
    fi
    
    # Extract working directory
    local working_dir=$(extract_working_directory "$tool_call")
    
    if [[ -z "$working_dir" ]]; then
        notify_user "SKIP" "Could not determine working directory"
        echo '{"action": "continue"}'
        exit 0
    fi
    
    # Find project root
    local project_root=$(find_project_root "$working_dir" || echo "")
    
    if [[ -z "$project_root" ]]; then
        notify_user "SKIP" "No registered project found for $working_dir"
        echo '{"action": "continue"}'
        exit 0
    fi
    
    # Check if project is registered and enabled
    if ! is_project_registered "$project_root"; then
        notify_user "SKIP" "Project not registered or disabled: $project_root"
        echo '{"action": "continue"}'
        exit 0
    fi
    
    # Route to project bridge
    echo "$tool_call" | route_to_project_bridge "$project_root" "$tool_name" "$tool_call"
}

# Auto-detect if running interactively and set notification level
if [[ -t 2 ]] && [[ -z "${GEMINI_ODDITY_NOTIFY:-}" ]]; then
    export GEMINI_ODDITY_NOTIFY="subtle"
fi

# Handle special commands (for testing/debugging)
if [[ "${1:-}" == "--status" ]]; then
    echo "Universal Router Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo "Version: $ROUTER_VERSION"
    echo "Registry: $BRIDGE_REGISTRY"
    echo "Notification: ${GEMINI_ODDITY_NOTIFY:-subtle}"
    
    if [[ -f "$BRIDGE_REGISTRY" ]]; then
        echo ""
        echo "Registered Projects:"
        jq -r '.projects | to_entries[] | "  ✓ \(.key) (v\(.value.bridge_version))"' "$BRIDGE_REGISTRY" 2>/dev/null || echo "  None"
    fi
    exit 0
fi

# Run main routing logic
main "$@"