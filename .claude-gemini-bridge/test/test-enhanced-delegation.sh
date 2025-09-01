#!/bin/bash

# Test script for enhanced delegation features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../hooks/config/debug.conf"
source "$SCRIPT_DIR/../hooks/lib/debug-helpers.sh"
source "$SCRIPT_DIR/../hooks/lib/enhanced-delegation.sh"

echo "╔════════════════════════════════════════════════════════╗"
echo "║   Testing Enhanced Delegation Logic                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

# Test 1: Keyword trigger test
echo "Test 1: Keyword Triggers"
echo "------------------------"
test_prompts=(
    "Please do a deep analysis of the codebase"
    "Think carefully about this problem"
    "Review all files in the project"
    "Help me plan the architecture"
    "Do a comprehensive PR review"
    "Simple task with no keywords"
)

for prompt in "${test_prompts[@]}"; do
    if check_keyword_triggers "$prompt"; then
        echo "✅ DELEGATE: '$prompt'"
    else
        echo "❌ NO DELEGATE: '$prompt'"
    fi
done
echo

# Test 2: Complexity scoring test
echo "Test 2: Complexity Scoring"
echo "-------------------------"
test_cases=(
    "Task:5:100000:Review and refactor entire codebase"
    "Task:2:5000:Simple analysis task"
    "Read:1:1000:Read single small file"
    "Grep:10:50000:Search across many files"
)

for test_case in "${test_cases[@]}"; do
    IFS=':' read -r tool file_count size prompt <<< "$test_case"
    score=$(calculate_complexity_score "$tool" "" "$prompt" "$file_count" "$size")
    if [ "$score" -gt "${COMPLEXITY_THRESHOLD:-6}" ]; then
        echo "✅ DELEGATE (score=$score/10): $prompt"
    else
        echo "❌ NO DELEGATE (score=$score/10): $prompt"
    fi
done
echo

# Test 3: File count threshold
echo "Test 3: File Count Threshold (now 2 files)"
echo "------------------------------------------"
echo "MIN_FILES_FOR_GEMINI is set to: ${MIN_FILES_FOR_GEMINI:-2}"
file_counts=(1 2 3 5)

for count in "${file_counts[@]}"; do
    if [ "$count" -ge "${MIN_FILES_FOR_GEMINI:-2}" ]; then
        echo "✅ DELEGATE: Task with $count files"
    else
        echo "❌ NO DELEGATE: Task with $count files"
    fi
done
echo

# Test 4: Token limit check
echo "Test 4: Token Limits (50k threshold)"
echo "------------------------------------"
echo "CLAUDE_TOKEN_LIMIT is set to: ${CLAUDE_TOKEN_LIMIT:-50000}"
sizes=(10000 50000 100000 300000)

for size in "${sizes[@]}"; do
    tokens=$((size / 4))
    if [ "$tokens" -gt "${CLAUDE_TOKEN_LIMIT:-50000}" ] && [ "$tokens" -le "${GEMINI_TOKEN_LIMIT:-800000}" ]; then
        echo "✅ DELEGATE: Content with ~$tokens tokens ($size bytes)"
    else
        echo "❌ NO DELEGATE: Content with ~$tokens tokens ($size bytes)"
    fi
done
echo

echo "╔════════════════════════════════════════════════════════╗"
echo "║   Configuration Summary                                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo "• Keyword matching: ${KEYWORD_MATCHING_ENABLED:-true}"
echo "• Complexity scoring: ${COMPLEXITY_SCORING_ENABLED:-true}"
echo "• Complexity threshold: ${COMPLEXITY_THRESHOLD:-6}/10"
echo "• Min files for delegation: ${MIN_FILES_FOR_GEMINI:-2}"
echo "• Claude token limit: ${CLAUDE_TOKEN_LIMIT:-50000}"
echo "• File size threshold: ${MIN_FILE_SIZE_FOR_GEMINI:-5120} bytes"
echo
echo "✨ Enhanced delegation logic is configured and ready!"