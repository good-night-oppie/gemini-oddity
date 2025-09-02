# GitHub MCP Automation Scripts for Oppie-DevKit

## 📋 Overview

This directory contains automation scripts for setting up GitHub MCP (Model Context Protocol) in projects that use oppie-devkit as a submodule. The scripts provide intelligent project detection, automated configuration, and comprehensive guidance for AI agents.

## 🗂️ Script Functions Explained

### 1. `github-mcp-setup.sh` - **Full Automation Engine**

**Primary Purpose**: Complete GitHub MCP configuration with intelligent project detection.

**Key Functions**:
- `detect_project_type()` - Identifies project relationship (parent/submodule/standalone)
- `get_project_info()` - Extracts project paths and names
- `install_github_mcp()` - Downloads and configures MCP server
- `verify_github_token()` - Validates GitHub API access
- `configure_claude_code()` - Updates global Claude Code settings
- `create_project_config()` - Creates project-specific configurations

**Use Case**: First-time setup or complete reconfiguration

### 2. `init-github-mcp.sh` - **Quick Interface**

**Primary Purpose**: Streamlined commands for common operations.

**Key Functions**:
- `quick_init()` - One-command setup with progress indicators
- `validate_token()` - Standalone GitHub token validation
- `show_project_info()` - Project structure analysis
- `show_status()` - Current MCP configuration status

**Use Case**: Daily operations, status checks, troubleshooting

### 3. `detect-project-type.sh` - **Project Analysis**

**Primary Purpose**: Comprehensive project structure analysis and recommendations.

**Key Functions**:
- `detect_project_type()` - Advanced project relationship detection
- `analyze_git()` - Git repository and submodule analysis
- `analyze_package_managers()` - Node.js, Python, and other package managers
- `analyze_claude_config()` - Existing Claude Code configuration analysis
- `generate_recommendations()` - Setup recommendations based on analysis

**Use Case**: Project discovery, setup planning, debugging

## 🎯 Usage Scenarios

### Scenario 1: First-Time Setup
```bash
# Quick setup
./init-github-mcp.sh init

# Or detailed setup
./github-mcp-setup.sh
```

### Scenario 2: Project Analysis
```bash
# Analyze current project
./detect-project-type.sh

# Check specific directory
./detect-project-type.sh /path/to/project
```

### Scenario 3: Status & Troubleshooting
```bash
# Check configuration status
./init-github-mcp.sh status

# Validate GitHub token
./init-github-mcp.sh validate ghp_xxxxx

# Show project information
./init-github-mcp.sh info
```

### Scenario 4: Maintenance
```bash
# Reconfigure existing setup
./init-github-mcp.sh init

# Full project analysis
./detect-project-type.sh
```

## 🔍 Project Type Detection Logic

### Parent Project (Contains oppie-devkit)
- **Detection**: `.gitmodules` exists and contains "oppie-devkit"
- **Setup Target**: Project root
- **Config Location**: `<project-root>/.claude/`
- **MCP Install**: `<project-root>/.github-mcp/`

### Submodule Project (IS oppie-devkit)
- **Detection**: Parent directory has `.gitmodules` referencing current directory
- **Setup Target**: Parent project root
- **Config Location**: `<parent-root>/.claude/`
- **MCP Install**: `<parent-root>/.github-mcp/`

### Standalone Project
- **Detection**: No `.gitmodules` references found
- **Setup Target**: Current directory
- **Config Location**: `<current-dir>/.claude/`
- **MCP Install**: `<current-dir>/.github-mcp/`

## 📁 Generated File Structure

After successful setup:
```
project-root/
├── .github-mcp/                     # MCP server installation
│   ├── package.json
│   ├── package-lock.json
│   └── node_modules/
│       └── @modelcontextprotocol/server-github/
├── .claude/                         # Project-specific configuration
│   ├── github-mcp-config.json       # MCP configuration
│   └── github-mcp-usage.md          # Usage guide
├── oppie-devkit/                    # Submodule (if applicable)
│   ├── scripts/                     # These automation scripts
│   │   ├── github-mcp-setup.sh      # Full automation
│   │   ├── init-github-mcp.sh       # Quick interface
│   │   └── detect-project-type.sh   # Project analysis
│   └── templates/
│       └── ai-agent-github-mcp-template.md
└── ~/.claude/settings.json         # Global Claude Code configuration
```

## 🤖 AI Agent Instructions

### Quick Setup Command
```bash
cd oppie-devkit/scripts && ./init-github-mcp.sh init
```

### Verification Commands
```bash
# Check status
./init-github-mcp.sh status

# Analyze project
./detect-project-type.sh

# Validate token
./init-github-mcp.sh validate <token>
```

### Success Criteria
- ✅ All status checks show green
- ✅ Claude Code restart loads GitHub MCP
- ✅ GitHub API operations work
- ✅ Project-specific configs created

## 🔧 Configuration Details

### Global Configuration (`~/.claude/settings.json`)
```json
{
  "mcpServers": {
    "github": {
      "command": "node",
      "args": ["<path>/.github-mcp/node_modules/@modelcontextprotocol/server-github/dist/index.js"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxx",
        "GITHUB_ORGANIZATION": "good-night-oppie",
        "GITHUB_DEFAULT_REPO": "<project-name>"
      }
    }
  }
}
```

### Project Configuration (`<project>/.claude/github-mcp-config.json`)
```json
{
  "mcpServers": { /* Same as global */ },
  "project": {
    "name": "<project-name>",
    "type": "oppie-devkit-project",
    "github_integration": true
  }
}
```

## 🚨 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x *.sh
   ```

2. **Node.js Not Found**
   ```bash
   # Install Node.js
   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Token Invalid**
   ```bash
   ./init-github-mcp.sh validate <new-token>
   ```

4. **Script Not Found**
   ```bash
   # Ensure you're in oppie-devkit/scripts directory
   cd oppie-devkit/scripts
   ```

### Debug Mode
```bash
# Run with verbose output
bash -x ./init-github-mcp.sh init
```

## 📚 Related Documentation

- [Complete Setup Guide](../docs/GITHUB-MCP-SETUP-GUIDE.md)
- [AI Agent Template](../templates/ai-agent-github-mcp-template.md)
- [GitHub MCP Server Documentation](https://github.com/github/github-mcp-server)
- [Claude Code MCP Documentation](https://docs.anthropic.com/claude-code/mcp)

## 🔄 Maintenance

### Regular Tasks
- Update MCP server: `cd .github-mcp && npm update`
- Rotate tokens when needed
- Verify configuration with `./init-github-mcp.sh status`

### Script Updates
Scripts are designed to be self-contained and version-agnostic. Update by pulling latest oppie-devkit changes.

## ✅ Success Indicators

After running any setup script, verify success with:

```bash
# All should show ✅ status
./init-github-mcp.sh status

# Claude Code should load GitHub MCP after restart
# GitHub operations should work in Claude Code sessions
```