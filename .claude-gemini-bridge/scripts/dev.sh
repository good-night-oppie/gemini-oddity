#!/bin/bash
# SPDX-FileCopyrightText: 2025 Yongbing Tang and contributors
# SPDX-License-Identifier: MIT

# Development script for hot-reload of both backend and frontend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Oppie Thunder Development Environment${NC}"

# Check if required tools are installed
check_requirements() {
    local missing_tools=()
    
    if ! command -v go &> /dev/null; then
        missing_tools+=("go")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_tools+=("node")
    fi
    
    if ! command -v npm &> /dev/null; then
        missing_tools+=("npm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
}

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down development servers...${NC}"
    kill $(jobs -p) 2>/dev/null || true
    echo -e "${GREEN}Development environment stopped${NC}"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Check requirements
check_requirements

# Install Go air for hot-reload if not installed
if ! command -v air &> /dev/null; then
    echo -e "${YELLOW}Installing air for Go hot-reload...${NC}"
    go install github.com/cosmtrek/air@latest
fi

# Start backend with hot-reload
echo -e "${GREEN}Starting Go backend with hot-reload...${NC}"
(
    cd backend
    if [ ! -f .air.toml ]; then
        air init
    fi
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    air -c .air.toml 2>&1 | sed 's/^/[BACKEND] /'
) &

# Start frontend with hot-reload
echo -e "${GREEN}Starting React frontend with hot-reload...${NC}"
(
    cd frontend
    if [ ! -d node_modules ]; then
        echo -e "${YELLOW}Installing frontend dependencies...${NC}"
        npm install
    fi
    npm run dev 2>&1 | sed 's/^/[FRONTEND] /'
) &

echo -e "${GREEN}✨ Development environment is running!${NC}"
echo -e "${GREEN}Backend: http://localhost:8080${NC}"
echo -e "${GREEN}Frontend: http://localhost:5173${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"

# Wait for all background jobs
wait