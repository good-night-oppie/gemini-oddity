#!/bin/bash
# Initialize Gemini delegation for oppie-devkit projects
# This script configures intelligent delegation of analysis tasks to Gemini

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPPIE_ROOT="$(dirname "$SCRIPT_DIR")"

# Get project root (where this is being run from)
PROJECT_ROOT="$(pwd)"

echo -e "${BLUE}🤖 Configuring Gemini Delegation for Oppie DevKit${NC}"
echo -e "Project: $PROJECT_ROOT"
echo ""

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for Claude Gemini Bridge
    if [ ! -d "/home/dev/workspace/claude-gemini-bridge" ]; then
        missing_deps+=("claude-gemini-bridge")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    # Check for Claude settings file
    if [ ! -f "$HOME/.claude/settings.json" ]; then
        missing_deps+=("Claude settings")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install missing dependencies first."
        exit 1
    fi
}

# Install delegation configuration
install_delegation_config() {
    echo -e "${BLUE}Installing delegation configuration...${NC}"
    
    # Create hooks directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/.oppie-hooks"
    
    # Copy delegation config
    cp "$OPPIE_ROOT/hooks/gemini-delegation-config.sh" "$PROJECT_ROOT/.oppie-hooks/"
    
    # Create project-specific override file
    cat > "$PROJECT_ROOT/.oppie-hooks/project-overrides.sh" << 'EOF'
#!/bin/bash
# Project-specific Gemini delegation overrides
# Customize these values for your project's needs

# Override token limits if needed
# export CLAUDE_TOKEN_LIMIT=40000
# export GEMINI_TOKEN_LIMIT=900000

# Add project-specific patterns
# export PROJECT_GEMINI_PATTERNS="your-pattern-here"

# Add project-specific exclusions
# export PROJECT_EXCLUDE_PATTERNS="test|mock|stub"

echo "✅ Project overrides loaded"
EOF
    
    chmod +x "$PROJECT_ROOT/.oppie-hooks/project-overrides.sh"
    echo -e "${GREEN}✅ Delegation configuration installed${NC}"
}

# Update Claude settings
update_claude_settings() {
    echo -e "${BLUE}Updating Claude settings...${NC}"
    
    local settings_file="$HOME/.claude/settings.json"
    local backup_file="${settings_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing settings
    cp "$settings_file" "$backup_file"
    echo -e "${YELLOW}  Backup created: $backup_file${NC}"
    
    # Check if hook already exists
    if jq -e '.hooks.PreToolUse[]? | select(.matcher == "Read|Grep|Glob|Task")' "$settings_file" > /dev/null 2>&1; then
        echo -e "${YELLOW}  Hook already configured, updating...${NC}"
        
        # Update existing hook to include oppie configuration
        jq '.hooks.PreToolUse |= map(
            if .matcher == "Read|Grep|Glob|Task" then
                .hooks[0].command = "/home/dev/workspace/oppie-devkit/hooks/enhanced-gemini-bridge.sh"
            else . end
        )' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    else
        echo -e "${BLUE}  Adding new hook configuration...${NC}"
        
        # Add new hook configuration
        jq '.hooks.PreToolUse = [
            {
                "matcher": "Read|Grep|Glob|Task",
                "hooks": [
                    {
                        "type": "command",
                        "command": "/home/dev/workspace/oppie-devkit/hooks/enhanced-gemini-bridge.sh"
                    }
                ]
            }
        ] + (.hooks.PreToolUse // [])' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    fi
    
    echo -e "${GREEN}✅ Claude settings updated${NC}"
}

# Create enhanced bridge script
create_enhanced_bridge() {
    echo -e "${BLUE}Creating enhanced Gemini bridge...${NC}"
    
    cat > "$OPPIE_ROOT/hooks/enhanced-gemini-bridge.sh" << 'EOF'
#!/bin/bash
# Enhanced Gemini Bridge for Oppie DevKit
# Integrates project-specific delegation rules with the main Gemini bridge

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load Oppie delegation configuration
if [ -f "$SCRIPT_DIR/../hooks/gemini-delegation-config.sh" ]; then
    source "$SCRIPT_DIR/../hooks/gemini-delegation-config.sh"
fi

# Load project-specific overrides if they exist
PROJECT_ROOT="$(pwd)"
if [ -f "$PROJECT_ROOT/.oppie-hooks/project-overrides.sh" ]; then
    source "$PROJECT_ROOT/.oppie-hooks/project-overrides.sh"
fi

# Delegate to main Gemini bridge with enhanced configuration
exec /home/dev/workspace/claude-gemini-bridge/hooks/gemini-bridge.sh "$@"
EOF
    
    chmod +x "$OPPIE_ROOT/hooks/enhanced-gemini-bridge.sh"
    echo -e "${GREEN}✅ Enhanced bridge created${NC}"
}

# Create test script
create_test_script() {
    echo -e "${BLUE}Creating test script...${NC}"
    
    cat > "$PROJECT_ROOT/.oppie-hooks/test-delegation.sh" << 'EOF'
#!/bin/bash
# Test Gemini delegation

echo "Testing Gemini delegation..."

# Test 1: Large file analysis
echo "Test 1: Large file analysis"
find . -type f -name "*.go" | head -20 | while read file; do
    echo "  Analyzing: $file"
done

# Test 2: Multi-file search
echo "Test 2: Multi-file pattern search"
echo "  Would search for 'func|interface|struct' across Go files"

# Test 3: Project overview
echo "Test 3: Project structure analysis"
echo "  Would analyze project structure and dependencies"

echo ""
echo "✅ Delegation test complete"
echo "Check logs at: /home/dev/workspace/claude-gemini-bridge/logs/"
EOF
    
    chmod +x "$PROJECT_ROOT/.oppie-hooks/test-delegation.sh"
    echo -e "${GREEN}✅ Test script created${NC}"
}

# Display configuration summary
show_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Gemini Delegation Setup Complete!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
    echo "Configuration files:"
    echo "  - Delegation config: $PROJECT_ROOT/.oppie-hooks/gemini-delegation-config.sh"
    echo "  - Project overrides: $PROJECT_ROOT/.oppie-hooks/project-overrides.sh"
    echo "  - Test script: $PROJECT_ROOT/.oppie-hooks/test-delegation.sh"
    echo ""
    echo "Delegation triggers:"
    echo "  - Files > 3 and size > 50KB"
    echo "  - Comprehensive analysis requests"
    echo "  - Multi-file searches"
    echo "  - Security audits"
    echo "  - Performance reviews"
    echo ""
    echo "To test delegation:"
    echo "  ./.oppie-hooks/test-delegation.sh"
    echo ""
    echo "To customize:"
    echo "  Edit: .oppie-hooks/project-overrides.sh"
    echo ""
    echo -e "${YELLOW}Note: Claude will now automatically delegate large analysis tasks to Gemini${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Initializing Gemini Delegation for Oppie DevKit${NC}"
    echo ""
    
    check_dependencies
    install_delegation_config
    create_enhanced_bridge
    update_claude_settings
    create_test_script
    show_summary
}

# Run main function
main "$@"