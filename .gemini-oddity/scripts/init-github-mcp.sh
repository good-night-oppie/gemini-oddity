#!/bin/bash

# Quick GitHub MCP Initialization Script
# This script provides a streamlined way to initialize GitHub MCP for oppie-devkit projects

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quick logging functions
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1"; }

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/github-mcp-setup.sh"

# Quick init function
quick_init() {
    info "GitHub MCP Quick Initialization"
    echo "=================================="
    
    # Check if setup script exists
    if [[ ! -f "$SETUP_SCRIPT" ]]; then
        error "Setup script not found at $SETUP_SCRIPT"
        exit 1
    fi
    
    # Check if already configured
    if [[ -f "$HOME/.claude/settings.json" ]] && grep -q "github" "$HOME/.claude/settings.json"; then
        success "GitHub MCP already configured!"
        
        # Show current config
        info "Current configuration:"
        if [[ -f "$HOME/.claude/settings.json" ]]; then
            grep -A 10 "github" "$HOME/.claude/settings.json" | grep -E "(GITHUB_|command|args)" || true
        fi
        
        read -p "Reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Keeping existing configuration"
            exit 0
        fi
    fi
    
    # Run setup script
    info "Running GitHub MCP setup..."
    bash "$SETUP_SCRIPT"
    
    success "GitHub MCP initialization complete!"
}

# Token validation function
validate_token() {
    local token="$1"
    
    if [[ -z "$token" ]]; then
        error "GitHub token is required"
        return 1
    fi
    
    info "Validating GitHub token..."
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user)
    
    if [[ "$response" == "200" ]]; then
        success "Token is valid"
        return 0
    else
        error "Token validation failed (HTTP $response)"
        return 1
    fi
}

# Project info function
show_project_info() {
    info "Project Information"
    echo "==================="
    
    local project_root
    project_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    echo "📁 Project root: $project_root"
    echo "📝 Project name: $(basename "$project_root")"
    
    # Check if it's a git repository
    if git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1; then
        echo "🔗 Git repository: Yes"
        local remote_url
        remote_url=$(git -C "$project_root" remote get-url origin 2>/dev/null || echo "No origin remote")
        echo "🌐 Remote URL: $remote_url"
    else
        echo "🔗 Git repository: No"
    fi
    
    # Check for submodules
    if [[ -f "$project_root/.gitmodules" ]]; then
        echo "📦 Has submodules: Yes"
        grep "path = " "$project_root/.gitmodules" | sed 's/.*path = /  - /' || true
    else
        echo "📦 Has submodules: No"
    fi
    
    # Check if this IS a submodule
    if [[ -f "$project_root/../.gitmodules" ]] && grep -q "$(basename "$project_root")" "$project_root/../.gitmodules"; then
        echo "📦 Is submodule: Yes"
    else
        echo "📦 Is submodule: No"
    fi
    
    echo ""
}

# Usage function
usage() {
    echo "GitHub MCP Initialization Script for Oppie-DevKit Projects"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  init, setup     - Run full GitHub MCP setup"
    echo "  info            - Show project information"
    echo "  validate TOKEN  - Validate GitHub token"
    echo "  status          - Show current MCP status"
    echo "  help            - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init                           # Interactive setup"
    echo "  $0 validate ghp_xxxxxxxxxxxx     # Validate token"
    echo "  $0 info                          # Show project info"
    echo "  $0 status                        # Check MCP status"
    echo ""
}

# Status function
show_status() {
    info "GitHub MCP Status"
    echo "=================="
    
    # Check Claude Code settings
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        if grep -q "github" "$HOME/.claude/settings.json"; then
            success "GitHub MCP configured in Claude Code"
            
            # Extract configuration details
            if command -v jq >/dev/null 2>&1; then
                local org
                org=$(jq -r '.mcpServers.github.env.GITHUB_ORGANIZATION // "not set"' "$HOME/.claude/settings.json" 2>/dev/null)
                local repo
                repo=$(jq -r '.mcpServers.github.env.GITHUB_DEFAULT_REPO // "not set"' "$HOME/.claude/settings.json" 2>/dev/null)
                echo "🏢 Organization: $org"
                echo "📁 Default repo: $repo"
            fi
        else
            warning "GitHub MCP not configured in Claude Code"
        fi
    else
        warning "Claude Code settings file not found"
    fi
    
    # Check project-specific config
    local project_root
    project_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    if [[ -f "$project_root/.claude/github-mcp-config.json" ]]; then
        success "Project-specific GitHub MCP config found"
    else
        warning "No project-specific GitHub MCP config"
    fi
    
    # Check MCP server installation
    local common_paths=(
        "$project_root/.github-mcp/node_modules/@modelcontextprotocol/server-github"
        "$project_root/node_modules/@modelcontextprotocol/server-github"
        "$HOME/.local/lib/node_modules/@modelcontextprotocol/server-github"
    )
    
    local found_server=false
    for path in "${common_paths[@]}"; do
        if [[ -d "$path" ]]; then
            success "GitHub MCP server found at: $path"
            found_server=true
            break
        fi
    done
    
    if [[ "$found_server" == false ]]; then
        warning "GitHub MCP server not found in common locations"
    fi
    
    echo ""
}

# Main function
main() {
    case "${1:-init}" in
        "init"|"setup")
            show_project_info
            quick_init
            ;;
        "info")
            show_project_info
            ;;
        "validate")
            if [[ -z "$2" ]]; then
                error "Token required for validation"
                echo "Usage: $0 validate <github-token>"
                exit 1
            fi
            validate_token "$2"
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            error "Unknown command: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"