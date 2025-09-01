# Migration from claude-gemini-bridge to gemini-oddity

## Changes Made

1. **Project Name**: claude-gemini-bridge → gemini-oddity
2. **Directory**: ~/.claude-gemini-bridge → ~/.gemini-oddity  
3. **Config Path**: ~/.claude-gemini-bridge/config.json → ~/.gemini-oddity/config.json
4. **All References**: Updated throughout the codebase

## User Action Required

If you have an existing installation, please:

1. Backup your current configuration:
   ```bash
   cp -r ~/.claude-gemini-bridge ~/.claude-gemini-bridge.backup
   ```

2. Move configuration to new location:
   ```bash
   mv ~/.claude-gemini-bridge ~/.gemini-oddity
   ```

3. Update Claude settings:
   Edit `~/.claude/settings.json` and update the hook paths to use `.gemini-oddity`

4. Reinstall:
   ```bash
   ./install.sh
   ```

## Verification

Run the following to verify the migration:
```bash
./verify-installation.sh
```
