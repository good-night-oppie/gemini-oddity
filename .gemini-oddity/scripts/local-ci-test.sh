#!/bin/bash
# Local CI test script to verify code would pass CI

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Running local CI tests..."

# Check SPDX headers
echo -n "Checking SPDX headers... "
missing_headers=0
for file in $(find . -name "*.go" -not -path "./blue_team/*" -not -path "./.git/*"); do
    if ! head -n 3 "$file" | grep -q "SPDX-License-Identifier: MIT"; then
        echo -e "${RED}Missing SPDX header in: $file${NC}"
        missing_headers=$((missing_headers + 1))
    fi
done

if [ $missing_headers -eq 0 ]; then
    echo -e "${GREEN}✓ All Go files have SPDX headers${NC}"
else
    echo -e "${RED}✗ Found $missing_headers files without SPDX headers${NC}"
    exit 1
fi

# Check project structure
echo -n "Checking project structure... "
required_files=(
    "README.md"
    "LICENSE"
    "Makefile"
    "backend/go.mod"
    "backend/cmd/oppie-thunder/main.go"
)

all_present=true
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Required file missing: $file${NC}"
        all_present=false
    fi
done

if [ "$all_present" = true ]; then
    echo -e "${GREEN}✓ All required files present${NC}"
else
    exit 1
fi

# Check for blue_team references
echo -n "Checking for blue_team references... "
if grep -r "blue_team" --include="*.go" --exclude-dir=".git" --exclude-dir="blue_team" . 2>/dev/null; then
    echo -e "${RED}✗ Found references to blue_team in implementation files!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ No blue_team references found${NC}"
fi

echo -e "${GREEN}All local CI checks passed!${NC}"
echo "Note: Go compilation and tests would run in actual CI but require Go runtime."