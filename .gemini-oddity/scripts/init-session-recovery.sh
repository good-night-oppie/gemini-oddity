#!/bin/bash

# Initialize Claude Code Session Recovery Hook in current project
# This script copies and configures the session recovery hook from oppie-devkit templates

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory (oppie-devkit location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPPIE_DEVKIT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="${OPPIE_DEVKIT_ROOT}/templates/claude-hooks/session-recovery"

# Get current project root
PROJECT_ROOT="$(pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.claude-hooks"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

echo -e "${GREEN}Claude Code Session Recovery Hook Initialization${NC}"
echo "================================================="
echo "Project: ${PROJECT_ROOT}"
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Not in a git repository. It's recommended to initialize this in a git repo.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create hooks directory
mkdir -p "${HOOKS_DIR}"
echo -e "${GREEN}✓${NC} Created hooks directory: ${HOOKS_DIR}"

# Copy and configure the template
HOOK_SCRIPT="${HOOKS_DIR}/claude-session-recovery.py"
cp "${TEMPLATE_DIR}/claude-session-recovery.py.template" "${HOOK_SCRIPT}"

# Replace template variables
sed -i "s|{{PROJECT_ROOT}}|${PROJECT_ROOT}|g" "${HOOK_SCRIPT}"

# Make executable
chmod +x "${HOOK_SCRIPT}"
echo -e "${GREEN}✓${NC} Installed recovery hook: ${HOOK_SCRIPT}"

# Create or update Claude settings
echo -e "\n${YELLOW}Updating Claude Code settings...${NC}"

# Ensure Claude settings directory exists
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

# Check if settings file exists
if [ ! -f "$CLAUDE_SETTINGS" ]; then
    echo -e "${YELLOW}Creating new Claude settings file...${NC}"
    cat > "$CLAUDE_SETTINGS" << EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PostError": []
  }
}
EOF
fi

# Update settings using jq
if command -v jq >/dev/null 2>&1; then
    # Backup settings
    cp "$CLAUDE_SETTINGS" "${CLAUDE_SETTINGS}.backup"
    
    # Check if our hook already exists
    if jq -e '.hooks.PostError[] | select(.matcher == "No conversation found with session ID")' "$CLAUDE_SETTINGS" > /dev/null 2>&1; then
        echo -e "${YELLOW}Updating existing session recovery hook...${NC}"
        # Update the command path
        jq --arg cmd "$HOOK_SCRIPT" '.hooks.PostError = [.hooks.PostError[] | if .matcher == "No conversation found with session ID" then .hooks[0].command = $cmd else . end]' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp"
    else
        echo -e "${GREEN}Adding session recovery hook...${NC}"
        # Add new hook
        jq --arg cmd "$HOOK_SCRIPT" '
            if .hooks.PostError then
                .hooks.PostError += [{
                    "matcher": "No conversation found with session ID",
                    "hooks": [{
                        "type": "command",
                        "command": $cmd
                    }]
                }]
            else
                .hooks.PostError = [{
                    "matcher": "No conversation found with session ID",
                    "hooks": [{
                        "type": "command",
                        "command": $cmd
                    }]
                }]
            end
        ' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp"
    fi
    
    mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
    echo -e "${GREEN}✓${NC} Updated Claude settings"
else
    echo -e "${RED}Warning: jq not installed. Please manually add the hook to ${CLAUDE_SETTINGS}${NC}"
    echo "Add this to the hooks.PostError array:"
    echo '  {
    "matcher": "No conversation found with session ID",
    "hooks": [{
      "type": "command",
      "command": "'${HOOK_SCRIPT}'"
    }]
  }'
fi

# Create .gitignore for hooks directory if in git repo
if git rev-parse --git-dir > /dev/null 2>&1; then
    GITIGNORE="${HOOKS_DIR}/.gitignore"
    if [ ! -f "$GITIGNORE" ]; then
        cat > "$GITIGNORE" << EOF
# Session recovery logs
*.log

# Temporary files
*.tmp
EOF
        echo -e "${GREEN}✓${NC} Created .gitignore for hooks directory"
    fi
fi

# Create README for the project
README="${HOOKS_DIR}/README.md"
cat > "$README" << EOF
# Claude Code Hooks

This directory contains hooks to enhance Claude Code functionality for this project.

## Session Recovery Hook

Automatically recovers lost Claude Code sessions from workspace projects.

### How it works

When you get a "No conversation found with session ID" error, this hook:
1. Searches for the session in workspace projects
2. Copies essential session data to this project
3. Allows you to retry the operation

### Logs

Debug logs are stored in: \`session-recovery.log\`

### Troubleshooting

View logs: \`tail -f ${HOOKS_DIR}/session-recovery.log\`

### Source

This hook was initialized from oppie-devkit templates.
To update: \`oppie-devkit/scripts/init-session-recovery.sh\`
EOF

echo -e "${GREEN}✓${NC} Created hooks README"

# Final instructions
echo
echo -e "${GREEN}✅ Session Recovery Hook Initialized Successfully!${NC}"
echo
echo "The hook will activate automatically when you encounter session errors."
echo
echo -e "${YELLOW}Important:${NC} Restart Claude Code for the changes to take effect."
echo
echo "Hook location: ${HOOK_SCRIPT}"
echo "Debug logs: ${HOOKS_DIR}/session-recovery.log"
echo
echo "To test the hook manually:"
echo "  echo 'No conversation found with session ID: test-123' | ${HOOK_SCRIPT}"