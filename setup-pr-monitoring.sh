#!/bin/bash
# Setup PR monitoring for gemini-oddity

set -e

echo "🔧 Setting up PR monitoring for gemini-oddity..."

# Backup current settings
cp ~/.claude/settings.json ~/.claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)

# Update settings to use gemini-oddity PR monitoring
cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/home/dev/workspace/claude-gemini-bridge/hooks/pr-review/pr-monitor.sh",
            "conditions": {
              "patterns": [
                "git push.*feat",
                "git push origin",
                "gh pr create",
                "gh pr comment.*@claude"
              ]
            },
            "description": "Monitor PR and CI status after push"
          }
        ]
      }
    ]
  },
  "tools": {
    "preToolUse": "/home/dev/.claude/hooks/universal-router.sh"
  },
  "statusLine": {
    "type": "command",
    "command": "printf '\\033[01;32m%s@%s\\033[00m:\\033[01;34m%s\\033[00m' \"$(whoami)\" \"$(hostname -s)\" \"$(pwd)\""
  }
}
EOF

echo "✅ PR monitoring configured!"
echo ""
echo "The following actions will trigger PR monitoring:"
echo "  - git push to feature branches"
echo "  - gh pr create"
echo "  - gh pr comment with @claude"
echo ""
echo "Monitor will automatically:"
echo "  - Track PR status"
echo "  - Watch CI/CD progress"
echo "  - Report review comments"
echo "  - Alert on failures"