#!/bin/bash

# GitHub MCP Setup Script for Oppie-DevKit Submodule Projects
# This script automatically configures GitHub MCP for Claude Code in projects where oppie-devkit is a submodule

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.claude"
GITHUB_TOKEN=""
GITHUB_ORG="good-night-oppie"
DEFAULT_REPO=""

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect if this is a submodule project
detect_project_type() {
    if [[ -f "$PROJECT_ROOT/.gitmodules" ]] && grep -q "oppie-devkit" "$PROJECT_ROOT/.gitmodules"; then
        echo "parent"
    elif [[ -f "$PROJECT_ROOT/../.gitmodules" ]] && grep -q "oppie-devkit" "$PROJECT_ROOT/../.gitmodules"; then
        echo "submodule"
    else
        echo "standalone"
    fi
}

# Get project information
get_project_info() {
    local project_type="$1"
    local project_name
    local project_path
    
    case "$project_type" in
        "parent")
            project_path="$PROJECT_ROOT"
            project_name=$(basename "$PROJECT_ROOT")
            ;;
        "submodule")
            project_path="$(cd "$PROJECT_ROOT/.." && pwd)"
            project_name=$(basename "$project_path")
            ;;
        "standalone")
            project_path="$PROJECT_ROOT"
            project_name=$(basename "$PROJECT_ROOT")
            ;;
    esac
    
    echo "$project_path|$project_name"
}

# Check if GitHub MCP is already configured
check_existing_config() {
    if [[ -f "$CLAUDE_CONFIG_DIR/settings.json" ]] && grep -q "github" "$CLAUDE_CONFIG_DIR/settings.json"; then
        return 0
    else
        return 1
    fi
}

# Install GitHub MCP server if not present
install_github_mcp() {
    local install_path="$1"
    
    log_info "Installing GitHub MCP server to $install_path..."
    
    # Create directory if it doesn't exist
    mkdir -p "$install_path"
    
    # Check if package.json exists, create if not
    if [[ ! -f "$install_path/package.json" ]]; then
        cat > "$install_path/package.json" << EOF
{
  "name": "github-mcp-server",
  "version": "1.0.0",
  "description": "GitHub MCP server for Claude Code",
  "dependencies": {
    "@modelcontextprotocol/server-github": "latest"
  }
}
EOF
    fi
    
    # Install dependencies
    cd "$install_path"
    npm install
    
    log_success "GitHub MCP server installed successfully"
}

# Create or update Claude Code configuration
configure_claude_code() {
    local github_token="$1"
    local github_org="$2"
    local default_repo="$3"
    local mcp_server_path="$4"
    
    log_info "Configuring Claude Code with GitHub MCP..."
    
    # Create .claude directory if it doesn't exist
    mkdir -p "$CLAUDE_CONFIG_DIR"
    
    # Backup existing settings
    if [[ -f "$CLAUDE_CONFIG_DIR/settings.json" ]]; then
        cp "$CLAUDE_CONFIG_DIR/settings.json" "$CLAUDE_CONFIG_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create or update settings.json
    cat > "$CLAUDE_CONFIG_DIR/settings.json" << EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "mcpServers": {
    "github": {
      "command": "node",
      "args": [
        "$mcp_server_path/node_modules/@modelcontextprotocol/server-github/dist/index.js"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$github_token",
        "GITHUB_ORGANIZATION": "$github_org",
        "GITHUB_DEFAULT_REPO": "$default_repo"
      }
    }
  }
}
EOF
    
    log_success "Claude Code configuration updated"
}

# Create project-specific MCP configuration
create_project_config() {
    local project_path="$1"
    local project_name="$2"
    local github_token="$3"
    local github_org="$4"
    
    log_info "Creating project-specific GitHub MCP configuration..."
    
    # Create .claude directory in project if it doesn't exist
    mkdir -p "$project_path/.claude"
    
    cat > "$project_path/.claude/github-mcp-config.json" << EOF
{
  "mcpServers": {
    "github": {
      "command": "node",
      "args": [
        "$project_path/node_modules/@modelcontextprotocol/server-github/dist/index.js"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$github_token",
        "GITHUB_ORGANIZATION": "$github_org",
        "GITHUB_DEFAULT_REPO": "$project_name"
      }
    }
  },
  "project": {
    "name": "$project_name",
    "type": "oppie-devkit-project",
    "github_integration": true
  }
}
EOF
    
    log_success "Project-specific configuration created"
}

# Verify GitHub token
verify_github_token() {
    local token="$1"
    
    log_info "Verifying GitHub token..."
    
    local response
    response=$(curl -s -w "%{http_code}" -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user)
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "200" ]]; then
        log_success "GitHub token verified successfully"
        return 0
    else
        log_error "GitHub token verification failed (HTTP $http_code)"
        return 1
    fi
}

# Main setup function
main() {
    log_info "Starting GitHub MCP setup for Oppie-DevKit project..."
    
    # Detect project type
    local project_type
    project_type=$(detect_project_type)
    log_info "Detected project type: $project_type"
    
    # Get project information
    local project_info
    project_info=$(get_project_info "$project_type")
    local project_path
    project_path=$(echo "$project_info" | cut -d'|' -f1)
    local project_name
    project_name=$(echo "$project_info" | cut -d'|' -f2)
    
    log_info "Project path: $project_path"
    log_info "Project name: $project_name"
    
    # Check for existing configuration
    if check_existing_config; then
        log_warning "GitHub MCP already configured in Claude Code"
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping configuration update"
            exit 0
        fi
    fi
    
    # Get GitHub token
    if [[ -z "$GITHUB_TOKEN" ]]; then
        read -s -p "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
        echo
    fi
    
    # Verify token
    if ! verify_github_token "$GITHUB_TOKEN"; then
        log_error "Invalid GitHub token. Please check your token and try again."
        exit 1
    fi
    
    # Set default repo if not provided
    if [[ -z "$DEFAULT_REPO" ]]; then
        DEFAULT_REPO="$project_name"
    fi
    
    # Install GitHub MCP server
    local mcp_install_path="$project_path/.github-mcp"
    install_github_mcp "$mcp_install_path"
    
    # Configure Claude Code
    configure_claude_code "$GITHUB_TOKEN" "$GITHUB_ORG" "$DEFAULT_REPO" "$mcp_install_path"
    
    # Create project-specific config
    create_project_config "$project_path" "$project_name" "$GITHUB_TOKEN" "$GITHUB_ORG"
    
    log_success "GitHub MCP setup completed successfully!"
    log_info "Please restart Claude Code to load the new configuration."
    
    # Create usage guide
    cat > "$project_path/.claude/github-mcp-usage.md" << 'EOF'
# GitHub MCP Usage Guide

## Available Commands

Once Claude Code is restarted, you can use GitHub MCP commands:

### Repository Operations
- Create, fork, and manage repositories
- Access repository information and metadata
- Clone and manage local repositories

### Issue Management
- Create, read, update, and close issues
- Manage labels and assignees
- Track issue progress

### Pull Request Management
- Create and manage pull requests
- Review and merge workflows
- Handle conflicts and discussions

### File Operations
- Read and write repository files
- Create and manage branches
- Commit and push changes

### Organization Operations
- Access organization repositories
- Manage team and member permissions
- Organization-wide operations

## Example Usage

Ask Claude Code to:
- "Create a new issue in the current repository"
- "Fork the upstream repository"
- "Create a pull request for this branch"
- "List all open issues in the project"
- "Show repository information"

## Configuration

Your GitHub MCP is configured with:
- Organization: good-night-oppie
- Default Repository: [project-name]
- Authentication: Personal Access Token

For more information, see the oppie-devkit documentation.
EOF

    log_success "Usage guide created at $project_path/.claude/github-mcp-usage.md"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi