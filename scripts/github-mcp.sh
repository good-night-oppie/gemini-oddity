#!/bin/bash

# GitHub MCP Master Script for Oppie-DevKit
# Unified interface for all GitHub MCP operations

set -e

# Colors and icons
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logo and header
show_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 GitHub MCP Manager                     ║"
    echo "║                   Oppie-DevKit Integration                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Show main menu
show_menu() {
    echo -e "${BLUE}Available Commands:${NC}"
    echo ""
    echo -e "  ${GREEN}🚀 Quick Commands${NC}"
    echo "    setup, init          Quick GitHub MCP setup"
    echo "    status              Show current configuration status"
    echo "    info                Display project information"
    echo ""
    echo -e "  ${GREEN}🔍 Analysis${NC}"
    echo "    analyze             Full project structure analysis"
    echo "    detect              Detect project type and relationships"
    echo ""
    echo -e "  ${GREEN}🔧 Maintenance${NC}"
    echo "    validate <token>    Validate GitHub Personal Access Token"
    echo "    update              Update GitHub MCP server"
    echo "    reset               Reset configuration"
    echo ""
    echo -e "  ${GREEN}📚 Documentation${NC}"
    echo "    help                Show this help menu"
    echo "    guide               Open setup guide"
    echo "    docs                List available documentation"
    echo ""
    echo -e "  ${GREEN}🧪 Testing${NC}"
    echo "    test                Run configuration tests"
    echo "    debug               Debug mode with verbose output"
    echo ""
}

# Quick setup
quick_setup() {
    echo -e "${CYAN}🚀 Starting GitHub MCP Quick Setup${NC}"
    echo "======================================"
    
    if [[ -f "$SCRIPT_DIR/init-github-mcp.sh" ]]; then
        "$SCRIPT_DIR/init-github-mcp.sh" init
    else
        echo -e "${RED}❌ Init script not found${NC}"
        exit 1
    fi
}

# Show status
show_status() {
    echo -e "${CYAN}📊 GitHub MCP Configuration Status${NC}"
    echo "=================================="
    
    if [[ -f "$SCRIPT_DIR/init-github-mcp.sh" ]]; then
        "$SCRIPT_DIR/init-github-mcp.sh" status
    else
        echo -e "${RED}❌ Status script not found${NC}"
        exit 1
    fi
}

# Show project info
show_info() {
    echo -e "${CYAN}📋 Project Information${NC}"
    echo "======================"
    
    if [[ -f "$SCRIPT_DIR/init-github-mcp.sh" ]]; then
        "$SCRIPT_DIR/init-github-mcp.sh" info
    else
        echo -e "${RED}❌ Info script not found${NC}"
        exit 1
    fi
}

# Full analysis
run_analysis() {
    echo -e "${CYAN}🔍 Full Project Analysis${NC}"
    echo "========================="
    
    if [[ -f "$SCRIPT_DIR/detect-project-type.sh" ]]; then
        "$SCRIPT_DIR/detect-project-type.sh" "$@"
    else
        echo -e "${RED}❌ Detection script not found${NC}"
        exit 1
    fi
}

# Validate token
validate_token() {
    local token="$1"
    
    if [[ -z "$token" ]]; then
        echo -e "${RED}❌ GitHub token required${NC}"
        echo "Usage: $0 validate <github-token>"
        exit 1
    fi
    
    echo -e "${CYAN}🔐 Validating GitHub Token${NC}"
    echo "=========================="
    
    if [[ -f "$SCRIPT_DIR/init-github-mcp.sh" ]]; then
        "$SCRIPT_DIR/init-github-mcp.sh" validate "$token"
    else
        echo -e "${RED}❌ Validation script not found${NC}"
        exit 1
    fi
}

# Update MCP server
update_mcp() {
    echo -e "${CYAN}📦 Updating GitHub MCP Server${NC}"
    echo "=============================="
    
    # Find MCP installation
    local project_root
    project_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    local mcp_path="$project_root/.github-mcp"
    
    if [[ -d "$mcp_path" ]]; then
        echo -e "${GREEN}🔄 Updating MCP server at $mcp_path${NC}"
        cd "$mcp_path"
        npm update @modelcontextprotocol/server-github
        echo -e "${GREEN}✅ Update complete${NC}"
    else
        echo -e "${YELLOW}⚠️  MCP server not found. Run setup first.${NC}"
    fi
}

# Reset configuration
reset_config() {
    echo -e "${CYAN}🔄 Resetting GitHub MCP Configuration${NC}"
    echo "====================================="
    
    read -p "Are you sure you want to reset the configuration? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Removing configurations...${NC}"
        
        # Remove project configs
        local project_root
        project_root="$(cd "$SCRIPT_DIR/.." && pwd)"
        [[ -d "$project_root/.claude" ]] && rm -rf "$project_root/.claude"
        [[ -d "$project_root/.github-mcp" ]] && rm -rf "$project_root/.github-mcp"
        
        echo -e "${GREEN}✅ Configuration reset complete${NC}"
        echo -e "${BLUE}ℹ️  Run 'setup' to reconfigure${NC}"
    else
        echo -e "${BLUE}ℹ️  Reset cancelled${NC}"
    fi
}

# Show documentation
show_docs() {
    echo -e "${CYAN}📚 Available Documentation${NC}"
    echo "=========================="
    
    local docs_dir
    docs_dir="$(cd "$SCRIPT_DIR/.." && pwd)/docs"
    local templates_dir
    templates_dir="$(cd "$SCRIPT_DIR/.." && pwd)/templates"
    
    echo -e "${GREEN}📖 Guides:${NC}"
    [[ -f "$docs_dir/GITHUB-MCP-SETUP-GUIDE.md" ]] && echo "  • Setup Guide: $docs_dir/GITHUB-MCP-SETUP-GUIDE.md"
    [[ -f "$SCRIPT_DIR/README-GITHUB-MCP.md" ]] && echo "  • Scripts README: $SCRIPT_DIR/README-GITHUB-MCP.md"
    
    echo -e "${GREEN}🤖 Templates:${NC}"
    [[ -f "$templates_dir/ai-agent-github-mcp-template.md" ]] && echo "  • AI Agent Template: $templates_dir/ai-agent-github-mcp-template.md"
    
    echo -e "${GREEN}🔧 Scripts:${NC}"
    echo "  • Full Setup: $SCRIPT_DIR/github-mcp-setup.sh"
    echo "  • Quick Init: $SCRIPT_DIR/init-github-mcp.sh"
    echo "  • Project Detection: $SCRIPT_DIR/detect-project-type.sh"
    echo "  • Master Script: $SCRIPT_DIR/github-mcp.sh"
}

# Open setup guide
open_guide() {
    local guide_path
    guide_path="$(cd "$SCRIPT_DIR/.." && pwd)/docs/GITHUB-MCP-SETUP-GUIDE.md"
    
    if [[ -f "$guide_path" ]]; then
        echo -e "${CYAN}📖 Opening Setup Guide${NC}"
        echo "====================="
        echo "Guide location: $guide_path"
        
        # Try to open with available editors
        if command -v code >/dev/null; then
            code "$guide_path"
        elif command -v cat >/dev/null; then
            echo -e "${BLUE}📄 Guide Contents:${NC}"
            cat "$guide_path"
        fi
    else
        echo -e "${RED}❌ Setup guide not found${NC}"
    fi
}

# Run tests
run_tests() {
    echo -e "${CYAN}🧪 Running Configuration Tests${NC}"
    echo "==============================="
    
    local tests_passed=0
    local tests_total=0
    
    # Test 1: Script permissions
    ((tests_total++))
    echo -n "🔧 Script permissions... "
    if [[ -x "$SCRIPT_DIR/init-github-mcp.sh" ]] && [[ -x "$SCRIPT_DIR/detect-project-type.sh" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    # Test 2: Node.js availability
    ((tests_total++))
    echo -n "📦 Node.js availability... "
    if command -v node >/dev/null && command -v npm >/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    # Test 3: Git availability
    ((tests_total++))
    echo -n "🔗 Git availability... "
    if command -v git >/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    # Test 4: Claude Code config directory
    ((tests_total++))
    echo -n "📁 Claude Code config... "
    if [[ -d "$HOME/.claude" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} (will be created)"
    fi
    
    # Test 5: Network connectivity
    ((tests_total++))
    echo -n "🌐 GitHub API connectivity... "
    if curl -s --max-time 5 https://api.github.com/ >/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((tests_passed++))
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Test Results: $tests_passed/$tests_total passed${NC}"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        echo -e "${GREEN}🎉 All tests passed! Ready for setup.${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tests failed. Check requirements.${NC}"
    fi
}

# Debug mode
debug_mode() {
    echo -e "${CYAN}🐛 Debug Mode${NC}"
    echo "============="
    
    echo -e "${BLUE}Environment Information:${NC}"
    echo "Node.js: $(node --version 2>/dev/null || echo 'Not found')"
    echo "npm: $(npm --version 2>/dev/null || echo 'Not found')"
    echo "Git: $(git --version 2>/dev/null || echo 'Not found')"
    echo "Current directory: $(pwd)"
    echo "Script directory: $SCRIPT_DIR"
    echo ""
    
    echo -e "${BLUE}Running status with debug output:${NC}"
    bash -x "$SCRIPT_DIR/init-github-mcp.sh" status
}

# Main function
main() {
    show_header
    
    case "${1:-help}" in
        "setup"|"init")
            quick_setup
            ;;
        "status")
            show_status
            ;;
        "info")
            show_info
            ;;
        "analyze"|"detect")
            run_analysis "${@:2}"
            ;;
        "validate")
            validate_token "$2"
            ;;
        "update")
            update_mcp
            ;;
        "reset")
            reset_config
            ;;
        "guide")
            open_guide
            ;;
        "docs")
            show_docs
            ;;
        "test")
            run_tests
            ;;
        "debug")
            debug_mode
            ;;
        "help"|"-h"|"--help")
            show_menu
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $1${NC}"
            echo ""
            show_menu
            exit 1
            ;;
    esac
}

# Run main function
main "$@"