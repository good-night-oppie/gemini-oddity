# Enhanced Gemini Oddity Installer v2.0

## Overview

The Enhanced Installer provides a seamless, user-friendly experience for setting up the Gemini Oddity with per-project isolation, automatic OAuth management, and real-time activity notifications.

## Key Features

### 🎯 Per-Project Isolation
- **Universal Router**: Single global entry point that routes to project-specific bridges
- **Project Registry**: Automatic registration and management of multiple projects
- **Independent Configurations**: Each project can have different tool delegations

### 🔐 OAuth Management
- **Setup Wizard**: Interactive OAuth setup for first-time users
- **Auto-Refresh**: Tokens refresh automatically before expiry
- **Health Monitoring**: Continuous OAuth status checking
- **Cron Integration**: Optional background token refresh

### 🔔 Smart Notifications
- **Subtle Feedback**: Unobtrusive indicators when bridge is active
- **Configurable Levels**: quiet, subtle, verbose, debug modes
- **Activity Logging**: Complete audit trail of bridge operations
- **Real-time Status**: See when Gemini takes over operations

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/good-night-oppie/gemini-oddity.git
cd gemini-oddity

# Run the enhanced installer
./scripts/install-bridge.sh
```

### What Happens During Installation

1. **Prerequisites Check**
   - Verifies Claude CLI is installed
   - Checks for Gemini CLI
   - Ensures jq is available

2. **OAuth Setup**
   - Checks current authentication status
   - Guides through Google OAuth if needed
   - Tests connection to verify setup

3. **Bridge Installation**
   - Copies bridge files to `.gemini-oddity/`
   - Installs universal router to `~/.claude/hooks/`
   - Registers project in global registry

4. **Configuration**
   - Choose which tools to delegate (Read, Grep, Glob, Task)
   - Set up notification preferences
   - Optional: Enable automatic token refresh

## Usage

### CLI Commands

```bash
# Install in current directory
gemini-oddity install

# Check status
gemini-oddity status

# List all projects
gemini-oddity list

# View activity logs
gemini-oddity logs

# Manage OAuth
gemini-oddity auth-status
gemini-oddity auth-setup
gemini-oddity auth-refresh

# Enable/disable for current project
gemini-oddity enable
gemini-oddity disable

# Uninstall from current project
gemini-oddity uninstall
```

### Notification Levels

Control how much feedback you see:

```bash
# Quiet - no terminal output
export CLAUDE_BRIDGE_NOTIFY=quiet

# Subtle - minimal indicators (default)
export CLAUDE_BRIDGE_NOTIFY=subtle

# Verbose - full notifications
export CLAUDE_BRIDGE_NOTIFY=verbose

# Debug - everything with timestamps
export CLAUDE_BRIDGE_NOTIFY=debug
```

### Visual Indicators

When `CLAUDE_BRIDGE_NOTIFY=subtle` (default):
- 🌉 - Bridge is delegating to Gemini
- ⚠️ - Error or warning occurred

When `CLAUDE_BRIDGE_NOTIFY=verbose`:
- 🌉 Bridge: Analyzing 15 files with Gemini...
- 🌉 Bridge: Analysis complete (2.3s)
- 🌉 Bridge: Using cached response

## Architecture

### Universal Router

The universal router (`~/.claude/hooks/universal-router.sh`) acts as a single entry point for all Claude tool calls:

1. **Intercepts** tool calls from Claude
2. **Detects** current working directory
3. **Finds** registered project root
4. **Routes** to project-specific bridge
5. **Falls back** to normal Claude operation if no bridge found

### Project Registry

Located at `~/.claude/bridge-registry.json`:

```json
{
  "version": "2.0.0",
  "projects": {
    "/home/user/project-a": {
      "registered": "2024-01-15T10:30:00Z",
      "bridge_version": "2.0.0",
      "config": {
        "tools": "Read|Grep|Glob|Task",
        "enabled": true
      }
    }
  }
}
```

### OAuth Token Management

The OAuth manager handles:
- **Token Validation**: Checks expiry before each use
- **Auto-Refresh**: Refreshes tokens with 5-minute buffer
- **Fallback**: Gracefully falls back to Claude on auth failure
- **Monitoring**: Optional background health checks

## Multi-Project Setup

### Scenario: Multiple Projects

```bash
# Project A - Full delegation
cd ~/projects/web-app
gemini-oddity install
# Choose: All tools (Read, Grep, Glob, Task)

# Project B - Task-only delegation
cd ~/projects/api-server
gemini-oddity install
# Choose: Task operations only

# Project C - Custom selection
cd ~/projects/data-pipeline
gemini-oddity install
# Choose: Custom (Read|Task)

# View all projects
gemini-oddity list
```

### Result

Each project operates independently:
- Project A: All tools delegated to Gemini
- Project B: Only Task operations use Gemini
- Project C: Read and Task operations use Gemini

## OAuth Workflow

### First-Time Setup

1. **Detection**: Installer checks for existing OAuth
2. **Wizard**: Interactive setup if not authenticated
3. **Browser**: Opens Google sign-in page
4. **Authorization**: User authorizes Gemini CLI
5. **Verification**: Tests connection with simple query
6. **Success**: Stores credentials in `~/.gemini/oauth_creds.json`

### Automatic Refresh

```bash
# Token about to expire (< 5 minutes)
# Bridge automatically refreshes by calling:
gemini -p "test" -q "1"

# Optional: Setup cron for background refresh
# Runs every 45 minutes to keep token fresh
*/45 * * * * gemini -p test -q '1+1' >/dev/null 2>&1
```

## Troubleshooting

### Common Issues

#### OAuth Problems

```bash
# Check current status
gemini-oddity auth-status

# Manual refresh
gemini-oddity auth-refresh

# Complete re-authentication
gemini-oddity auth-setup
```

#### Bridge Not Activating

```bash
# Verify installation
gemini-oddity status

# Check if project is registered
gemini-oddity list

# Enable if disabled
gemini-oddity enable

# Test components
gemini-oddity test
```

#### Wrong Project Detected

```bash
# Check working directory detection
pwd
gemini-oddity status

# Re-register current directory
gemini-oddity uninstall
gemini-oddity install
```

### Debug Mode

Enable detailed logging:

```bash
# Terminal output
export CLAUDE_BRIDGE_NOTIFY=debug

# File logging
export DEBUG=1

# View logs
gemini-oddity logs
tail -f ~/.claude/bridge-status.log
```

## Uninstallation

### Remove from Project

```bash
# From project directory
gemini-oddity uninstall
# or
.gemini-oddity/uninstall.sh
```

### Complete Removal

```bash
# Remove all projects
gemini-oddity list | while read project; do
  gemini-oddity uninstall "$project"
done

# Remove universal router
rm ~/.claude/hooks/universal-router.sh

# Clean registry
rm ~/.claude/bridge-registry.json

# Remove logs
rm ~/.claude/bridge-status.log
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_BRIDGE_NOTIFY` | `subtle` | Notification level (quiet/subtle/verbose/debug) |
| `DEBUG` | `0` | Enable debug output (0/1) |
| `CLAUDE_BRIDGE_PROJECT_ROOT` | - | Override project root detection |

## Migration from v1.x

If you have the old bridge installed:

1. **Backup** existing settings
2. **Uninstall** old version
3. **Install** new version with `./scripts/install-bridge.sh`
4. **Verify** with `gemini-oddity status`

The new version maintains backward compatibility while adding:
- Per-project isolation
- Better OAuth management
- User notifications
- Multi-project support

## Testing

Run the test suite:

```bash
# All tests
./test/run-all-tests.sh

# Installer tests only
./test/unit/test-installer.sh

# OAuth tests
./test/unit/test-oauth-manager.sh
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines.

## Support

- **Issues**: [GitHub Issues](https://github.com/good-night-oppie/gemini-oddity/issues)
- **Discussions**: [GitHub Discussions](https://github.com/good-night-oppie/gemini-oddity/discussions)
- **Documentation**: [Full Docs](https://github.com/good-night-oppie/gemini-oddity/wiki)