#!/bin/bash

# Project Type Detection Script for Oppie-DevKit
# Provides detailed analysis of project structure and GitHub MCP setup recommendations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
INFO="ℹ"
SUCCESS="✅"
WARNING="⚠"
ERROR="❌"
FOLDER="📁"
FILE="📝"
GIT="🔗"
PACKAGE="📦"

# Logging functions
log() { echo -e "${BLUE}${INFO}${NC} $1"; }
success() { echo -e "${GREEN}${SUCCESS}${NC} $1"; }
warning() { echo -e "${YELLOW}${WARNING}${NC} $1"; }
error() { echo -e "${RED}${ERROR}${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
OPPIE_DEVKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Project type detection
detect_project_type() {
    local current_dir="$1"
    local project_info=()
    
    log "Analyzing project structure from: $current_dir"
    echo ""
    
    # Check if current directory is oppie-devkit
    if [[ "$(basename "$current_dir")" == "oppie-devkit" ]]; then
        project_info+=("type:submodule")
        project_info+=("name:$(basename "$(dirname "$current_dir")")")
        project_info+=("root:$(dirname "$current_dir")")
        echo -e "${CYAN}${PACKAGE}${NC} Current directory IS oppie-devkit submodule"
    else
        # Check if current directory contains oppie-devkit
        if [[ -d "$current_dir/oppie-devkit" ]]; then
            project_info+=("type:parent")
            project_info+=("name:$(basename "$current_dir")")
            project_info+=("root:$current_dir")
            echo -e "${CYAN}${PACKAGE}${NC} Current directory CONTAINS oppie-devkit submodule"
        else
            project_info+=("type:standalone")
            project_info+=("name:$(basename "$current_dir")")
            project_info+=("root:$current_dir")
            echo -e "${CYAN}${PACKAGE}${NC} Standalone project (no oppie-devkit relationship)"
        fi
    fi
    
    # Output project info
    for info in "${project_info[@]}"; do
        echo "$info"
    done
}

# Git analysis
analyze_git() {
    local project_root="$1"
    
    echo -e "\n${CYAN}${GIT} Git Repository Analysis${NC}"
    echo "================================"
    
    if git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1; then
        success "Git repository detected"
        
        # Remote information
        local origin_url
        origin_url=$(git -C "$project_root" remote get-url origin 2>/dev/null || echo "none")
        echo -e "${FOLDER} Remote origin: $origin_url"
        
        # Branch information
        local current_branch
        current_branch=$(git -C "$project_root" branch --show-current 2>/dev/null || echo "unknown")
        echo -e "${FOLDER} Current branch: $current_branch"
        
        # Submodule analysis
        if [[ -f "$project_root/.gitmodules" ]]; then
            success "Submodules configuration found"
            echo -e "${FILE} Submodules:"
            while IFS= read -r line; do
                if [[ "$line" =~ path\ =\ (.+) ]]; then
                    local submodule_path="${BASH_REMATCH[1]}"
                    echo -e "  ${PACKAGE} $submodule_path"
                    
                    # Check if it's oppie-devkit
                    if [[ "$submodule_path" == *"oppie-devkit"* ]]; then
                        success "  → oppie-devkit submodule found"
                    fi
                fi
            done < "$project_root/.gitmodules"
        else
            warning "No submodules configuration"
        fi
        
        # Check if current directory is a submodule
        if [[ -f "$project_root/../.gitmodules" ]]; then
            local parent_dir
            parent_dir="$(dirname "$project_root")"
            if grep -q "$(basename "$project_root")" "$parent_dir/.gitmodules"; then
                success "This directory is a submodule of parent project"
            fi
        fi
        
    else
        warning "Not a Git repository"
    fi
}

# Package manager analysis
analyze_package_managers() {
    local project_root="$1"
    
    echo -e "\n${CYAN}${PACKAGE} Package Manager Analysis${NC}"
    echo "==================================="
    
    # Node.js
    if [[ -f "$project_root/package.json" ]]; then
        success "Node.js project (package.json found)"
        
        if command -v node >/dev/null 2>&1; then
            echo -e "${SUCCESS} Node.js version: $(node --version)"
        else
            warning "Node.js not installed"
        fi
        
        if command -v npm >/dev/null 2>&1; then
            echo -e "${SUCCESS} npm version: $(npm --version)"
        else
            warning "npm not available"
        fi
        
        # Check for GitHub MCP dependencies
        if grep -q "@modelcontextprotocol/server-github" "$project_root/package.json" 2>/dev/null; then
            success "GitHub MCP server dependency found"
        else
            warning "GitHub MCP server not in dependencies"
        fi
        
    else
        warning "No package.json found"
    fi
    
    # Python
    if [[ -f "$project_root/requirements.txt" ]] || [[ -f "$project_root/pyproject.toml" ]] || [[ -f "$project_root/setup.py" ]]; then
        success "Python project detected"
        
        if command -v python3 >/dev/null 2>&1; then
            echo -e "${SUCCESS} Python version: $(python3 --version)"
        fi
        
        if command -v pip >/dev/null 2>&1; then
            echo -e "${SUCCESS} pip available"
        fi
    fi
    
    # Other package managers
    [[ -f "$project_root/Cargo.toml" ]] && success "Rust project (Cargo.toml)"
    [[ -f "$project_root/go.mod" ]] && success "Go project (go.mod)"
    [[ -f "$project_root/composer.json" ]] && success "PHP project (composer.json)"
}

# Claude Code analysis
analyze_claude_config() {
    local project_root="$1"
    
    echo -e "\n${CYAN}${FILE} Claude Code Configuration${NC}"
    echo "=================================="
    
    # Global Claude Code config
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        success "Global Claude Code configuration found"
        
        if grep -q "github" "$HOME/.claude/settings.json"; then
            success "GitHub MCP configured globally"
            
            # Extract organization if possible
            if command -v jq >/dev/null 2>&1; then
                local org
                org=$(jq -r '.mcpServers.github.env.GITHUB_ORGANIZATION // "not set"' "$HOME/.claude/settings.json" 2>/dev/null)
                local repo
                repo=$(jq -r '.mcpServers.github.env.GITHUB_DEFAULT_REPO // "not set"' "$HOME/.claude/settings.json" 2>/dev/null)
                echo -e "${INFO} Organization: $org"
                echo -e "${INFO} Default repo: $repo"
            fi
        else
            warning "GitHub MCP not configured globally"
        fi
    else
        warning "No global Claude Code configuration"
    fi
    
    # Project-specific config
    if [[ -f "$project_root/.claude/github-mcp-config.json" ]]; then
        success "Project-specific GitHub MCP config found"
    else
        warning "No project-specific GitHub MCP config"
    fi
    
    # Check for existing MCP installations
    local mcp_locations=(
        "$project_root/.github-mcp"
        "$project_root/node_modules/@modelcontextprotocol/server-github"
        "$HOME/.local/lib/node_modules/@modelcontextprotocol/server-github"
    )
    
    local found_mcp=false
    for location in "${mcp_locations[@]}"; do
        if [[ -d "$location" ]]; then
            success "GitHub MCP server found at: $location"
            found_mcp=true
        fi
    done
    
    if [[ "$found_mcp" == false ]]; then
        warning "GitHub MCP server not found in common locations"
    fi
}

# Generate recommendations
generate_recommendations() {
    local project_type="$1"
    local project_root="$2"
    local project_name="$3"
    
    echo -e "\n${CYAN}${SUCCESS} Setup Recommendations${NC}"
    echo "============================="
    
    case "$project_type" in
        "parent")
            echo -e "${SUCCESS} Recommended setup for parent project:"
            echo "  1. Run GitHub MCP setup from oppie-devkit:"
            echo "     cd oppie-devkit/scripts && ./init-github-mcp.sh init"
            echo "  2. GitHub MCP will be installed at: $project_root/.github-mcp/"
            echo "  3. Project name will be: $project_name"
            ;;
        "submodule")
            echo -e "${SUCCESS} Recommended setup for submodule project:"
            echo "  1. Run GitHub MCP setup from current location:"
            echo "     ./init-github-mcp.sh init"
            echo "  2. GitHub MCP will be installed at: $project_root/.github-mcp/"
            echo "  3. Project name will be: $project_name"
            ;;
        "standalone")
            echo -e "${SUCCESS} Recommended setup for standalone project:"
            echo "  1. If oppie-devkit is copied (not submodule):"
            echo "     cd oppie-devkit/scripts && ./init-github-mcp.sh init"
            echo "  2. Or run setup directly if scripts are available"
            echo "  3. GitHub MCP will be installed at: $project_root/.github-mcp/"
            echo "  4. Project name will be: $project_name"
            ;;
    esac
    
    echo ""
    echo -e "${INFO} Additional recommendations:"
    
    # Node.js recommendations
    if [[ ! -f "$project_root/package.json" ]] && [[ "$project_type" != "submodule" ]]; then
        echo "  • Consider initializing Node.js project: npm init -y"
    fi
    
    # Git recommendations
    if ! git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1; then
        echo "  • Initialize Git repository: git init"
    fi
    
    # Claude Code recommendations
    if [[ ! -f "$HOME/.claude/settings.json" ]]; then
        echo "  • Create Claude Code configuration directory: mkdir -p ~/.claude"
    fi
    
    echo "  • After setup, restart Claude Code to load GitHub MCP"
    echo "  • Test GitHub MCP with: ./init-github-mcp.sh status"
}

# Main analysis function
main() {
    local target_dir
    target_dir="${1:-$(pwd)}"
    
    echo -e "${CYAN}Oppie-DevKit Project Analysis${NC}"
    echo "==============================="
    echo -e "${INFO} Target directory: $target_dir"
    echo ""
    
    # Detect project type
    local project_data
    project_data=$(detect_project_type "$target_dir")
    local project_type
    project_type=$(echo "$project_data" | grep "type:" | cut -d':' -f2)
    local project_name
    project_name=$(echo "$project_data" | grep "name:" | cut -d':' -f2)
    local project_root
    project_root=$(echo "$project_data" | grep "root:" | cut -d':' -f2)
    
    echo -e "\n${CYAN}${INFO} Project Summary${NC}"
    echo "======================"
    echo -e "${FOLDER} Type: $project_type"
    echo -e "${FILE} Name: $project_name"
    echo -e "${FOLDER} Root: $project_root"
    
    # Run analyses
    analyze_git "$project_root"
    analyze_package_managers "$project_root"
    analyze_claude_config "$project_root"
    generate_recommendations "$project_type" "$project_root" "$project_name"
    
    echo ""
    echo -e "${SUCCESS} Analysis complete!"
    echo -e "${INFO} To proceed with GitHub MCP setup, run:"
    echo -e "${YELLOW}    ./init-github-mcp.sh init${NC}"
}

# Show usage
usage() {
    echo "Project Type Detection Script for Oppie-DevKit"
    echo ""
    echo "Usage: $0 [directory]"
    echo ""
    echo "Arguments:"
    echo "  directory    Target directory to analyze (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Analyze current directory"
    echo "  $0 /path/to/project   # Analyze specific directory"
    echo "  $0 ../my-project      # Analyze relative directory"
    echo ""
}

# Handle arguments
case "${1:-}" in
    "-h"|"--help"|"help")
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac