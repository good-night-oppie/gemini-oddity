#!/bin/bash
# Initialize TDD hooks for oppie-devkit projects
# This script installs pre-commit and post-push hooks for automated CI/CD validation

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPPIE_ROOT="$(dirname "$SCRIPT_DIR")"

# Get project root (where this is being run from)
PROJECT_ROOT="$(pwd)"

echo "🪝 Installing TDD hooks for oppie-devkit..."
echo "Project: $PROJECT_ROOT"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    echo "Please run this from your project root directory."
    exit 1
fi

# Get git hooks directory
GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Function to install hook
install_hook() {
    local hook_name=$1
    local template_path="$OPPIE_ROOT/templates/hooks/$hook_name"
    local target_path="$GIT_HOOKS_DIR/$hook_name"
    
    if [[ ! -f "$template_path" ]]; then
        echo -e "${RED}❌ Error: Template not found: $template_path${NC}"
        return 1
    fi
    
    # Check if hook already exists
    if [[ -f "$target_path" ]]; then
        echo -e "${YELLOW}⚠️  Hook already exists: $hook_name${NC}"
        echo -n "Overwrite? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Skipping $hook_name"
            return 0
        fi
    fi
    
    # Copy and make executable
    cp "$template_path" "$target_path"
    chmod +x "$target_path"
    
    echo -e "${GREEN}✅ Installed: $hook_name${NC}"
}

# Install hooks
echo "Installing Git hooks..."
install_hook "pre-commit"
install_hook "post-push"

echo ""
echo -e "${GREEN}✅ TDD hooks installed successfully!${NC}"
echo ""
echo "The following hooks are now active:"
echo "  • pre-commit: Runs local tests before committing"
echo "  • post-push: Monitors CI/CD status after pushing"
echo ""
echo "To test the hooks:"
echo "  1. Make a change to a file"
echo "  2. git add ."
echo "  3. git commit -m 'test' (pre-commit will run)"
echo "  4. git push (post-push will monitor CI/CD)"
echo ""
echo "To bypass hooks temporarily:"
echo "  • git commit --no-verify"
echo "  • git push --no-verify"