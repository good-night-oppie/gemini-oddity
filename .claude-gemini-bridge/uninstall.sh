#!/bin/bash
# Project-specific uninstaller

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIDGE_REGISTRY="$HOME/.claude/bridge-registry.json"

echo "🗑️  Uninstalling Claude-Gemini Bridge from $PROJECT_DIR"

# Remove from registry
if [[ -f "$BRIDGE_REGISTRY" ]]; then
    temp_registry=$(mktemp)
    jq --arg dir "$PROJECT_DIR" 'del(.projects[$dir])' "$BRIDGE_REGISTRY" > "$temp_registry"
    mv "$temp_registry" "$BRIDGE_REGISTRY"
    echo "✅ Project unregistered"
fi

# Remove bridge directory
rm -rf "$PROJECT_DIR/.claude-gemini-bridge"
echo "✅ Bridge files removed"

echo "🎉 Uninstall complete!"
