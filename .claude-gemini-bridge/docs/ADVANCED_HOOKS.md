# Advanced Hooks System for Claude-Gemini Bridge

## Overview

The Claude-Gemini Bridge now includes an advanced hooks system that provides:
- **Automated PR review monitoring** with Claude debate protocol
- **CI/CD status tracking** and auto-fix attempts  
- **Complexity-based reviewer personas** for thorough code review
- **Evidence-based debate responses** with test results and metrics
- **Unified automation** that coordinates all monitoring activities

## Architecture

```
Claude Code
    ├── PreToolUse Hooks (Gemini Delegation)
    │   └── gemini-bridge.sh → Delegates large tasks to Gemini
    │
    └── PostToolUse Hooks (PR & CI Monitoring)
        ├── unified-automation.sh → Coordinates all automation
        ├── pr-review/pr-monitor.sh → Monitors PR reviews
        └── Detects: git push, gh pr create, @claude mentions
```

## Installation

### Quick Install

```bash
# From the claude-gemini-bridge directory
./hooks/install-advanced-hooks.sh
```

This will:
1. Backup your existing Claude settings
2. Install PostToolUse hooks for PR monitoring
3. Configure unified automation
4. Set up helper aliases

### Manual Installation

If you prefer manual configuration, add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-gemini-bridge/hooks/pr-review/pr-monitor.sh detect \"${CLAUDE_TOOL_INPUT}\"",
            "conditions": {
              "patterns": [
                "git push.*origin",
                "gh pr create",
                "gh pr comment.*@claude"
              ]
            }
          }
        ]
      }
    ]
  }
}
```

## Features

### 1. Automatic PR Review Monitoring

When you push code or create a PR, the system:
- Detects the PR number from your branch
- Calculates complexity based on changes
- Monitors for Claude's review responses
- Handles multi-round debates automatically

### 2. Complexity-Based Reviewer Personas

| Complexity | Persona | Focus | Rounds |
|------------|---------|-------|---------|
| 9-10/10 | Chief Architect | Rigorous proof, empirical validation | 3-4 |
| 7-8/10 | Senior Engineer | Trade-offs, maintainability | 2-3 |
| 5-6/10 | Code Reviewer | Functionality, best practices | 1-2 |

### 3. Debate Protocol

The system handles three types of Claude responses:

#### Approval (✅)
- Marks PR as approved
- Cleans up monitoring state
- Posts celebration comment

#### Critical Issues (🔴)
- Collects evidence (tests, metrics)
- Generates defense response
- Continues debate with data

#### Questions (🟡)
- Provides detailed clarifications
- Addresses specific concerns
- Continues monitoring

### 4. Evidence Collection

For critical reviews, the system automatically:
- Runs test suites
- Executes ShellCheck validation
- Collects performance metrics
- Gathers cache statistics

## Usage

### Workflow Example

```bash
# 1. Make changes and commit
git add .
git commit -m "feat: Add new delegation logic

Complexity: 8/10"

# 2. Push to create/update PR
git push origin feature/my-branch

# System automatically:
# - Detects PR creation
# - Identifies complexity (8/10)
# - Starts monitoring

# 3. Request Claude review (for high complexity)
gh pr comment --body "@claude please review this PR"

# System automatically:
# - Posts specialized review request
# - Monitors for Claude's response
# - Handles debate rounds
# - Collects evidence as needed
```

### Manual Commands

```bash
# Start monitoring a PR
./hooks/pr-review/pr-monitor.sh monitor <pr_number> [complexity]

# Request review with specific complexity
./hooks/pr-review/pr-monitor.sh request <pr_number> [complexity] [domain]

# Check monitoring status
./hooks/pr-review/pr-monitor.sh status

# Stop monitoring
./hooks/pr-review/pr-monitor.sh stop <pr_number>
```

### Helper Aliases

After installation, source the aliases file:

```bash
source ./hooks/aliases.sh

# Then use shortcuts:
cgb-pr-monitor 123 8    # Monitor PR #123 with complexity 8
cgb-pr-status           # Show active monitors
cgb-pr-logs            # View PR monitoring logs
cgb-cache-clear        # Clear Gemini cache
```

## Configuration

### Complexity Hints

Add complexity to your commit messages or PR descriptions:

```markdown
Complexity: 8/10
Domain: shell/hooks
```

### Monitoring Settings

Edit `hooks/pr-review/pr-monitor.sh` to adjust:
- `CHECK_INTERVAL`: How often to check for comments (default: 120s)
- `CACHE_TTL`: Cache duration for PR data (default: 60s)
- Max debate rounds (default: 5)

## Integration with CI/CD

The system integrates with GitHub Actions:

1. **On PR creation**: Triggers review if complexity ≥ 7
2. **On push**: Monitors CI status
3. **On failure**: Can attempt auto-fixes
4. **On @claude mention**: Starts debate monitoring

## Troubleshooting

### Monitoring Not Starting

1. Check hooks are installed:
   ```bash
   grep "pr-monitor" ~/.claude/settings.json
   ```

2. Verify scripts are executable:
   ```bash
   ls -la hooks/pr-review/*.sh
   ```

3. Check logs:
   ```bash
   tail -f logs/pr-monitor.log
   tail -f logs/unified-automation.log
   ```

### Claude Not Responding

1. Ensure GitHub Actions are configured
2. Check secrets are set (CLAUDE_ACCESS_TOKEN, etc.)
3. Verify @claude mention in PR comment

### Evidence Collection Failing

1. Ensure test scripts exist and are executable
2. Check ShellCheck is installed
3. Verify write permissions in cache directory

## Advanced Features

### Custom Reviewer Personas

Edit `select_reviewer_persona()` in `pr-monitor.sh` to add domain-specific reviewers:

```bash
case $domain in
    "security")
        REVIEWER_ROLE="Security Expert"
        FOCUS_AREAS="Input validation, auth, cryptography"
        ;;
    "performance")
        REVIEWER_ROLE="Performance Engineer"
        FOCUS_AREAS="Optimization, caching, benchmarks"
        ;;
esac
```

### Auto-Fix Integration

The system can trigger auto-fixes for common issues:

```bash
# In handle_critical_review()
if echo "$concerns" | grep -q "shellcheck"; then
    # Auto-fix shellcheck issues
    find . -name "*.sh" | xargs shellcheck -f diff | patch -p1
    git commit -am "fix: Auto-fix ShellCheck issues"
    git push
fi
```

## Best Practices

1. **Always specify complexity** in PRs for accurate review depth
2. **Use semantic commit messages** for better context
3. **Let debates complete** - don't interrupt monitoring
4. **Review evidence** before accepting auto-fixes
5. **Monitor logs** during critical reviews

## Security Considerations

The system:
- Never exposes API keys or secrets
- Validates all inputs before processing
- Uses proper quoting in shell scripts
- Implements timeouts for all operations
- Cleans up sensitive data from cache

## Performance

- **Hook execution**: <1 second (runs in background)
- **PR detection**: <500ms with caching
- **Evidence collection**: 5-30 seconds depending on tests
- **Debate response**: 10-60 seconds with evidence

## Limitations

- Requires GitHub CLI (`gh`) for PR operations
- Needs repository write access for auto-fixes
- Limited to 5 debate rounds to prevent infinite loops
- Cache cleared after 1 hour for security

## Future Enhancements

- [ ] Integration with more CI/CD platforms
- [ ] Custom evidence collectors per domain
- [ ] Machine learning for complexity detection
- [ ] Automated PR merge on approval
- [ ] Multi-reviewer coordination
- [ ] Performance regression detection

## Contributing

To add new monitoring capabilities:

1. Create a new handler in `unified-automation.sh`
2. Add detection pattern in `extract_context()`
3. Implement evidence collection if needed
4. Update documentation

## Support

For issues or questions:
- Check logs in `logs/` directory
- Run diagnostic: `./hooks/pr-review/pr-monitor.sh status`
- Review this documentation
- Open an issue on GitHub