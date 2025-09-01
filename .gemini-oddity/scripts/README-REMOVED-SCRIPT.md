# Removed Script: init-project.sh

## Why This Script Was Removed

The `init-project.sh` script was designed for a completely different project ("Oppie Dockhand") and would have:

1. **Created incorrect directory structure** (core/, rag/, orchestration/, frontend/)
2. **Conflicted with DevKit philosophy** (DevKit copies tools TO projects, not transforms itself)
3. **Caused confusion** about the project's purpose and identity

## What It Was Trying To Do

The script was designed to transform oppie-devkit into a multi-service AI platform with:
- Rust MCTS engine
- Python RAG module  
- Go orchestration layer
- Next.js frontend
- Kubernetes deployment

This is **NOT** what oppie-devkit is supposed to be.

## Oppie DevKit's Actual Purpose

Oppie DevKit provides **templates and tools** that get copied to other projects:

```bash
# Correct usage - from a TARGET project
cd /path/to/my-project
./oppie-devkit/scripts/init-session-recovery.sh  # Copies tools to THIS project
./oppie-devkit/scripts/init-github-mcp.sh        # Configures tools for THIS project
```

## If You Need The Removed Functionality

If you need to create a new AI platform project similar to what the removed script was trying to create, you should:

1. **Create a new repository** for that project
2. **Use oppie-devkit as a submodule** in that new project
3. **Initialize the specific tools you need** from DevKit

Example:
```bash
mkdir my-ai-platform
cd my-ai-platform
git init
git submodule add https://github.com/your-org/oppie-devkit.git
./oppie-devkit/scripts/init-session-recovery.sh
# Add your own project structure as needed
```

## Related Files

The following files were also inconsistent with DevKit's purpose and have been corrected:
- `CLAUDE.md` - Now describes DevKit correctly
- `README_PROJECT.md` - Now focuses on DevKit tools
- `Makefile` - Now contains DevKit-appropriate tasks