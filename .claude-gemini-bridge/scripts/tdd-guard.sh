#!/bin/bash
# TDD Guard - Ensures all CI/CD checks pass before declaring success
# This script verifies GitHub Actions status and local tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub repository info
REPO_OWNER="good-night-oppie"
REPO_NAME="oppie-thunder"

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success") echo -e "${GREEN}✓${NC} $message" ;;
        "failure") echo -e "${RED}✗${NC} $message" ;;
        "warning") echo -e "${YELLOW}⚠${NC} $message" ;;
        "info") echo -e "${BLUE}ℹ${NC} $message" ;;
    esac
}

# Function to check GitHub Actions status
check_github_actions() {
    local wait_mode="${1:-nowait}"
    print_status "info" "Checking GitHub Actions status..."
    
    # Get the latest commit SHA
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    print_status "info" "Checking status for commit: ${commit_sha:0:7}"
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        print_status "warning" "GitHub CLI (gh) not found. Install it for remote status checks."
        return 1
    fi
    
    # Get workflow runs for the latest commit
    local workflows=("ci.yml")
    local all_passed=true
    local any_running=false
    
    for workflow in "${workflows[@]}"; do
        print_status "info" "Checking workflow: $workflow"
        
        # Get the latest run for this workflow
        local run_info
        run_info=$(gh run list \
            --workflow="$workflow" \
            --branch="$(git branch --show-current)" \
            --limit=1 \
            --json status,conclusion,headSha,id \
            --jq ".[] | select(.headSha==\"$commit_sha\")" \
            2>/dev/null || echo "{}")
        
        if [[ -z "$run_info" ]] || [[ "$run_info" == "{}" ]]; then
            print_status "warning" "$workflow: No runs found for this commit"
            if [[ "$wait_mode" == "wait" ]]; then
                any_running=true
            fi
            continue
        fi
        
        local run_status
        run_status=$(echo "$run_info" | jq -r '.status')
        local run_conclusion
        run_conclusion=$(echo "$run_info" | jq -r '.conclusion // "pending"')
        local run_id
        run_id=$(echo "$run_info" | jq -r '.id')
        
        if [[ "$run_status" == "in_progress" ]] || [[ "$run_status" == "queued" ]]; then
            print_status "warning" "$workflow: Currently $run_status"
            any_running=true
            all_passed=false
            
            if [[ -n "$run_id" ]]; then
                print_status "info" "Monitor at: https://github.com/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id"
            fi
        else
            case $run_conclusion in
                "success")
                    print_status "success" "$workflow: PASSED"
                    ;;
                "failure")
                    print_status "failure" "$workflow: FAILED"
                    all_passed=false
                    
                    if [[ -n "$run_id" ]]; then
                        print_status "info" "View details: https://github.com/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id"
                    fi
                    ;;
                *)
                    print_status "warning" "$workflow: Conclusion is $run_conclusion"
                    all_passed=false
                    ;;
            esac
        fi
    done
    
    # If in wait mode and workflows are running, wait and retry
    if [[ "$wait_mode" == "wait" ]] && [[ "$any_running" == "true" ]]; then
        print_status "info" "Workflows are still running. Waiting 30 seconds before retry..."
        sleep 30
        return 2  # Special code for retry
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to wait for GitHub Actions to complete
wait_for_github_actions() {
    local max_attempts=20  # 10 minutes max (30s * 20)
    local attempt=1
    
    print_status "info" "Waiting for GitHub Actions to complete..."
    echo "This may take several minutes..."
    
    while [[ $attempt -le $max_attempts ]]; do
        echo ""
        print_status "info" "Attempt $attempt of $max_attempts"
        
        check_github_actions "wait"
        local result=$?
        
        if [[ $result -eq 0 ]]; then
            return 0
        elif [[ $result -eq 1 ]]; then
            return 1
        fi
        
        # result is 2, continue waiting
        attempt=$((attempt + 1))
    done
    
    print_status "failure" "Timeout waiting for workflows to complete"
    return 1
}

# Function to run local tests
run_local_tests() {
    print_status "info" "Running local tests..."
    
    local all_passed=true
    
    # Check if all scripts are executable
    print_status "info" "Checking script permissions..."
    local non_executable=0
    for script in scripts/*.sh; do
        if [[ -f "$script" ]] && [[ ! -x "$script" ]]; then
            print_status "failure" "$script is not executable"
            non_executable=$((non_executable + 1))
            all_passed=false
        fi
    done
    
    if [[ $non_executable -eq 0 ]]; then
        print_status "success" "All scripts have executable permissions"
    fi
    
    # Run ShellCheck if available
    if command -v shellcheck &> /dev/null; then
        print_status "info" "Running ShellCheck..."
        if shellcheck scripts/*.sh; then
            print_status "success" "ShellCheck passed"
        else
            print_status "failure" "ShellCheck found issues"
            all_passed=false
        fi
    else
        print_status "warning" "ShellCheck not installed. Install it for shell script linting."
    fi
    
    # Run Go tests
    if [[ -d "backend" ]] && [[ -f "backend/go.mod" ]]; then
        print_status "info" "Running Go tests..."
        if (cd backend && go test ./... -race); then
            print_status "success" "Go tests passed"
        else
            print_status "failure" "Go tests failed"
            all_passed=false
        fi
    else
        print_status "warning" "Backend Go module not found"
    fi
    
    # Run frontend tests
    if [[ -d "frontend" ]] && [[ -f "frontend/package.json" ]]; then
        print_status "info" "Running frontend tests..."
        if (cd frontend && pnpm test run); then
            print_status "success" "Frontend tests passed"
        else
            print_status "failure" "Frontend tests failed"
            all_passed=false
        fi
    else
        print_status "warning" "Frontend package.json not found"
    fi
    
    # Check for common issues
    print_status "info" "Checking for common issues..."
    
    # Check for TODO comments
    local todo_count
    todo_count=$(grep -r "TODO" scripts/ templates/ --include="*.sh" --include="*.py" 2>/dev/null | wc -l || echo 0)
    if [[ $todo_count -gt 0 ]]; then
        print_status "warning" "Found $todo_count TODO comments"
    fi
    
    # Check for debugging statements
    local debug_count
    debug_count=$(grep -r "set -x\|echo \"DEBUG" scripts/ --include="*.sh" 2>/dev/null | wc -l || echo 0)
    if [[ $debug_count -gt 0 ]]; then
        print_status "warning" "Found $debug_count debugging statements"
    fi
    
    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to check git status
check_git_status() {
    print_status "info" "Checking git status..."
    
    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        print_status "warning" "You have uncommitted changes:"
        git status --short
        return 1
    else
        print_status "success" "Working directory is clean"
    fi
    
    # Check if we're up to date with remote
    git fetch origin &>/dev/null
    local LOCAL
    LOCAL=$(git rev-parse @)
    local REMOTE
    REMOTE=$(git rev-parse '@{u}' 2>/dev/null || echo "")
    
    if [[ -z "$REMOTE" ]]; then
        print_status "warning" "No upstream branch set"
    elif [[ "$LOCAL" = "$REMOTE" ]]; then
        print_status "success" "Branch is up to date with remote"
    else
        print_status "warning" "Branch has diverged from remote"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    echo "🛡️  TDD Guard for oppie-thunder"
    echo "================================"
    
    local exit_code=0
    
    # Check git status
    if ! check_git_status; then
        exit_code=1
    fi
    
    echo ""
    
    # Run local tests
    if ! run_local_tests; then
        exit_code=1
    fi
    
    echo ""
    
    # Check GitHub Actions (if available)
    if command -v gh &> /dev/null; then
        if ! check_github_actions; then
            exit_code=1
        fi
    else
        print_status "info" "Install GitHub CLI (gh) to check remote CI/CD status"
        print_status "info" "Visit: https://github.com/$REPO_OWNER/$REPO_NAME/actions"
    fi
    
    echo ""
    echo "================================"
    
    if [[ $exit_code -eq 0 ]]; then
        print_status "success" "All checks passed! ✨"
        echo -e "${GREEN}Your code is ready for deployment!${NC}"
    else
        print_status "failure" "Some checks failed"
        echo -e "${RED}Please fix the issues before proceeding${NC}"
    fi
    
    return $exit_code
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --local        Run only local tests"
        echo "  --remote       Check only GitHub Actions status"
        echo "  --wait         Wait for GitHub Actions to complete (post-push)"
        echo ""
        echo "TDD Guard ensures all CI/CD checks pass before declaring success."
        exit 0
        ;;
    --local)
        run_local_tests
        exit $?
        ;;
    --remote)
        check_github_actions
        exit $?
        ;;
    --wait)
        wait_for_github_actions
        exit $?
        ;;
    *)
        main
        exit $?
        ;;
esac