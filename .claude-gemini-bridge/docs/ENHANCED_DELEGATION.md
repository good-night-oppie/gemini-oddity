# Enhanced Delegation Configuration

## Overview
The Claude-Gemini Bridge now includes smart delegation logic inspired by best practices from the community. The bridge intelligently routes tasks to Gemini based on multiple criteria to optimize Claude's context window and leverage Gemini's 1M token capacity.

## Delegation Triggers (Applied Ideas)

### 1. **Keyword Matching** 🔍
Automatically delegates when these keywords are detected in prompts:
- **Deep analysis**: "deep", "depth", "think"
- **Comprehensive tasks**: "all files", "comprehensive", "thorough", "detailed analysis"
- **Architecture/Design**: "plan", "design", "architecture", "system design"
- **Code review**: "PR review", "review entire"
- **Direct request**: "gemini"

### 2. **File Count Threshold** 📁
- **Previous**: 3+ files
- **Now**: 2+ files (following the "超过两个文件" recommendation)
- Applies to Task operations

### 3. **Token Limits** 📊
- **Claude comfort zone**: 50k tokens (~200KB)
- **Gemini capacity**: 800k tokens (~3.2MB)
- Automatically delegates when content exceeds Claude's comfort zone

### 4. **Complexity Scoring** 🎯
Tasks scoring >6/10 are delegated. Score factors:
- **Tool type** (0-3 points): Task=3, Grep/Glob=2, Read=1
- **File count** (0-3 points): 10+=3, 5+=2, 2+=1
- **Size** (0-2 points): >100KB=2, >50KB=1
- **Prompt complexity** (0-2 points): refactor/redesign=2, analyze/review=1

## Configuration File
Location: `/home/dev/workspace/claude-gemini-bridge/hooks/config/debug.conf`

```bash
# Core thresholds
MIN_FILES_FOR_GEMINI=2          # Reduced from 3
MIN_FILE_SIZE_FOR_GEMINI=5120   # 5KB minimum
CLAUDE_TOKEN_LIMIT=50000        # ~200KB comfort zone

# New smart features
KEYWORD_MATCHING_ENABLED=true
GEMINI_TRIGGER_KEYWORDS="deep|depth|think|all files|plan|design|PR review|gemini|..."
COMPLEXITY_SCORING_ENABLED=true
COMPLEXITY_THRESHOLD=6          # Delegate if score >6/10
```

## Testing
Run the enhanced delegation test:
```bash
/home/dev/workspace/claude-gemini-bridge/test/test-enhanced-delegation.sh
```

## Examples

### Keyword Trigger
```
Prompt: "Please do a deep analysis of the codebase"
Result: ✅ Delegated to Gemini (keyword: "deep")
```

### Multi-File Task
```
Tool: Task
Files: 2 files
Result: ✅ Delegated to Gemini (meets 2-file threshold)
```

### Complexity Score
```
Tool: Task (3 points)
Files: 5 files (2 points)
Size: 150KB (2 points)
Prompt: "Refactor entire module" (2 points)
Total: 9/10
Result: ✅ Delegated to Gemini (score >6)
```

### Token Limit
```
Content: 300KB (~75k tokens)
Result: ✅ Delegated to Gemini (exceeds 50k comfort zone)
```

## Benefits
- **Token Efficiency**: Saves 70-90% of Claude's context for responses
- **Smart Routing**: Automatically detects complex tasks needing Gemini's power
- **Keyword Intelligence**: Responds to natural language cues for delegation
- **Complexity Awareness**: Scores tasks holistically, not just by size
- **Lower Thresholds**: More aggressive delegation for better performance

## Implementation Notes
The enhanced logic is implemented in:
- `/hooks/lib/enhanced-delegation.sh` - Core logic functions
- `/hooks/gemini-bridge.sh` - Main hook integration
- `/hooks/config/debug.conf` - Configuration settings

The system maintains backward compatibility while adding these intelligent features, making Claude-Gemini collaboration more efficient and cost-effective ("物美价廉").