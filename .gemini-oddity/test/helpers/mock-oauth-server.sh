#!/bin/bash
# ABOUTME: Mock OAuth server for isolated testing

# Mock server configuration
MOCK_SERVER_PORT="${MOCK_OAUTH_PORT:-8888}"
MOCK_SERVER_PID=""
MOCK_SERVER_LOG="${TEST_TMP_DIR:-/tmp}/mock-oauth-server.log"

# Mock responses
MOCK_ACCESS_TOKEN="mock_access_token_$(date +%s)"
MOCK_REFRESH_TOKEN="mock_refresh_token_$(date +%s)"
MOCK_AUTH_CODE="mock_auth_code_$(date +%s)"
MOCK_EXPIRES_IN=3600

# Start mock OAuth server
start_mock_oauth_server() {
    echo "Starting mock OAuth server on port $MOCK_SERVER_PORT..."
    
    # Create a simple HTTP server using netcat
    while true; do
        {
            # Read request
            read -r request_line
            read -r host_line
            
            # Parse request
            method=$(echo "$request_line" | cut -d' ' -f1)
            path=$(echo "$request_line" | cut -d' ' -f2)
            
            # Read headers
            while read -r header; do
                [ -z "$header" ] || [ "$header" = $'\r' ] && break
            done
            
            # Read body if present
            body=""
            if [ "$method" = "POST" ]; then
                read -r body
            fi
            
            # Route request
            case "$path" in
                "/auth")
                    # Authorization endpoint
                    echo "HTTP/1.1 302 Found"
                    echo "Location: http://localhost:8080/callback?code=$MOCK_AUTH_CODE&state=test"
                    echo "Content-Length: 0"
                    echo ""
                    ;;
                    
                "/token")
                    # Token endpoint
                    response=$(cat <<EOF
{
    "access_token": "$MOCK_ACCESS_TOKEN",
    "refresh_token": "$MOCK_REFRESH_TOKEN",
    "expires_in": $MOCK_EXPIRES_IN,
    "token_type": "Bearer",
    "scope": "test.scope"
}
EOF
)
                    echo "HTTP/1.1 200 OK"
                    echo "Content-Type: application/json"
                    echo "Content-Length: ${#response}"
                    echo ""
                    echo "$response"
                    ;;
                    
                "/revoke")
                    # Revocation endpoint
                    echo "HTTP/1.1 200 OK"
                    echo "Content-Length: 0"
                    echo ""
                    ;;
                    
                "/introspect")
                    # Token introspection endpoint
                    response=$(cat <<EOF
{
    "active": true,
    "exp": $(($(date +%s) + MOCK_EXPIRES_IN)),
    "scope": "test.scope",
    "client_id": "test_client_id"
}
EOF
)
                    echo "HTTP/1.1 200 OK"
                    echo "Content-Type: application/json"
                    echo "Content-Length: ${#response}"
                    echo ""
                    echo "$response"
                    ;;
                    
                "/api/test")
                    # Mock API endpoint
                    response='{"result": "test successful", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
                    echo "HTTP/1.1 200 OK"
                    echo "Content-Type: application/json"
                    echo "Content-Length: ${#response}"
                    echo ""
                    echo "$response"
                    ;;
                    
                *)
                    # 404 for unknown paths
                    echo "HTTP/1.1 404 Not Found"
                    echo "Content-Length: 0"
                    echo ""
                    ;;
            esac
        } | nc -l $MOCK_SERVER_PORT -N
    done >> "$MOCK_SERVER_LOG" 2>&1 &
    
    MOCK_SERVER_PID=$!
    
    # Wait for server to start
    sleep 1
    
    # Verify server is running
    if kill -0 $MOCK_SERVER_PID 2>/dev/null; then
        echo "Mock OAuth server started (PID: $MOCK_SERVER_PID)"
        return 0
    else
        echo "Failed to start mock OAuth server"
        return 1
    fi
}

# Stop mock OAuth server
stop_mock_oauth_server() {
    if [ -n "$MOCK_SERVER_PID" ]; then
        echo "Stopping mock OAuth server (PID: $MOCK_SERVER_PID)..."
        kill $MOCK_SERVER_PID 2>/dev/null || true
        wait $MOCK_SERVER_PID 2>/dev/null || true
        MOCK_SERVER_PID=""
    fi
    
    # Clean up any orphaned nc processes
    pkill -f "nc.*$MOCK_SERVER_PORT" 2>/dev/null || true
}

# Mock OAuth client functions
mock_oauth_authenticate() {
    # Simulate OAuth authentication flow
    echo "$MOCK_AUTH_CODE"
}

mock_exchange_code_for_token() {
    local code="$1"
    
    if [ "$code" = "$MOCK_AUTH_CODE" ]; then
        cat <<EOF
{
    "access_token": "$MOCK_ACCESS_TOKEN",
    "refresh_token": "$MOCK_REFRESH_TOKEN",
    "expires_in": $MOCK_EXPIRES_IN,
    "token_type": "Bearer"
}
EOF
        return 0
    else
        echo '{"error": "invalid_grant"}'
        return 1
    fi
}

mock_refresh_token() {
    local refresh_token="$1"
    
    if [ "$refresh_token" = "$MOCK_REFRESH_TOKEN" ]; then
        # Generate new tokens
        MOCK_ACCESS_TOKEN="mock_access_token_refreshed_$(date +%s)"
        
        cat <<EOF
{
    "access_token": "$MOCK_ACCESS_TOKEN",
    "expires_in": $MOCK_EXPIRES_IN,
    "token_type": "Bearer"
}
EOF
        return 0
    else
        echo '{"error": "invalid_token"}'
        return 1
    fi
}

mock_validate_token() {
    local token="$1"
    
    if [ "$token" = "$MOCK_ACCESS_TOKEN" ]; then
        echo '{"active": true}'
        return 0
    else
        echo '{"active": false}'
        return 1
    fi
}

# Mock API call
mock_api_call() {
    local token="$1"
    local endpoint="$2"
    local data="${3:-}"
    
    if [ "$token" != "$MOCK_ACCESS_TOKEN" ]; then
        echo '{"error": "unauthorized"}'
        return 1
    fi
    
    case "$endpoint" in
        "generateContent")
            echo '{"response": "Generated content from mock API"}'
            ;;
        "listModels")
            echo '{"models": ["gemini-pro", "gemini-pro-vision"]}'
            ;;
        *)
            echo '{"result": "success", "endpoint": "'$endpoint'"}'
            ;;
    esac
    
    return 0
}

# Simulate token expiration
expire_mock_token() {
    MOCK_ACCESS_TOKEN="expired_token"
}

# Reset mock server state
reset_mock_server() {
    MOCK_ACCESS_TOKEN="mock_access_token_$(date +%s)"
    MOCK_REFRESH_TOKEN="mock_refresh_token_$(date +%s)"
    MOCK_AUTH_CODE="mock_auth_code_$(date +%s)"
}

# Cleanup function
cleanup_mock_server() {
    stop_mock_oauth_server
    [ -f "$MOCK_SERVER_LOG" ] && rm -f "$MOCK_SERVER_LOG"
}

# Export functions and variables
export -f start_mock_oauth_server stop_mock_oauth_server
export -f mock_oauth_authenticate mock_exchange_code_for_token
export -f mock_refresh_token mock_validate_token mock_api_call
export -f expire_mock_token reset_mock_server cleanup_mock_server
export MOCK_ACCESS_TOKEN MOCK_REFRESH_TOKEN MOCK_AUTH_CODE
export MOCK_SERVER_PORT MOCK_SERVER_PID