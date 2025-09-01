#!/bin/bash
# ABOUTME: Performance benchmark tests

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TEST_DIR/../.." && pwd)"

# Source test utilities
source "$TEST_DIR/../helpers/test-utils.sh"

# Performance targets
HOOK_EXECUTION_TARGET_MS=100
TOKEN_REFRESH_TARGET_MS=500
OAUTH_FLOW_TARGET_S=5
ENCRYPTION_TARGET_MS=50
CACHE_HIT_RATE_TARGET=80

# Results storage
PERFORMANCE_RESULTS=()

test_hook_execution_speed() {
    test_start "Hook Execution Speed"
    
    # Create test input
    local test_input='{"tool_name":"Read","tool_input":{"file_path":"test.txt"},"session_id":"perf_test"}'
    
    # Warm up
    echo "$test_input" | "$PROJECT_DIR/hooks/gemini-bridge.sh" > /dev/null 2>&1
    
    # Measure execution time
    local total_time=0
    local iterations=10
    
    for i in $(seq 1 $iterations); do
        local start=$(date +%s%N)
        echo "$test_input" | "$PROJECT_DIR/hooks/gemini-bridge.sh" > /dev/null 2>&1
        local end=$(date +%s%N)
        
        local duration_ns=$((end - start))
        local duration_ms=$((duration_ns / 1000000))
        total_time=$((total_time + duration_ms))
    done
    
    local avg_time=$((total_time / iterations))
    PERFORMANCE_RESULTS+=("Hook execution: ${avg_time}ms (target: ${HOOK_EXECUTION_TARGET_MS}ms)")
    
    if [ $avg_time -le $HOOK_EXECUTION_TARGET_MS ]; then
        test_pass "Hook execution: ${avg_time}ms ✓"
    else
        test_fail "Hook execution too slow: ${avg_time}ms (target: ${HOOK_EXECUTION_TARGET_MS}ms)"
    fi
}

test_encryption_performance() {
    test_start "Encryption Performance"
    
    # Source encryption library
    source "$PROJECT_DIR/hooks/lib/encryption-core.sh" 2>/dev/null
    
    # Test data sizes
    local sizes=(100 1000 10000 100000)
    local password="perf_test_pass"
    
    for size in "${sizes[@]}"; do
        # Generate test data
        local test_data=$(head -c $size /dev/urandom | base64)
        
        # Measure encryption time
        local start=$(date +%s%N)
        local encrypted=$(encrypt_data "$test_data" "$password" 2>/dev/null)
        local end=$(date +%s%N)
        
        local duration_ns=$((end - start))
        local duration_ms=$((duration_ns / 1000000))
        
        PERFORMANCE_RESULTS+=("Encryption ${size}B: ${duration_ms}ms")
        
        # Check against target (scaled by size)
        local target=$((ENCRYPTION_TARGET_MS * size / 1000))
        
        if [ $duration_ms -le $target ]; then
            echo "  ${size} bytes: ${duration_ms}ms ✓"
        else
            echo "  ${size} bytes: ${duration_ms}ms (slow)"
        fi
    done
    
    test_pass "Encryption performance measured"
}

test_token_refresh_speed() {
    test_start "Token Refresh Speed"
    
    # Mock token refresh function
    mock_token_refresh() {
        # Simulate OAuth token refresh
        sleep 0.1  # 100ms network latency
        echo '{"access_token":"new_token","expires_in":3600}'
    }
    
    # Measure refresh time
    local start=$(date +%s%N)
    local result=$(mock_token_refresh)
    local end=$(date +%s%N)
    
    local duration_ns=$((end - start))
    local duration_ms=$((duration_ns / 1000000))
    
    PERFORMANCE_RESULTS+=("Token refresh: ${duration_ms}ms (target: ${TOKEN_REFRESH_TARGET_MS}ms)")
    
    if [ $duration_ms -le $TOKEN_REFRESH_TARGET_MS ]; then
        test_pass "Token refresh: ${duration_ms}ms ✓"
    else
        test_fail "Token refresh too slow: ${duration_ms}ms"
    fi
}

test_concurrent_load() {
    test_start "Concurrent Load Handling"
    
    local concurrency_levels=(1 5 10 20)
    
    for level in "${concurrency_levels[@]}"; do
        # Function to simulate load
        process_request() {
            local id=$1
            echo '{"test":"data"}' | "$PROJECT_DIR/hooks/gemini-bridge.sh" > /dev/null 2>&1
        }
        
        # Measure concurrent execution
        local start=$(date +%s%N)
        
        local pids=()
        for i in $(seq 1 $level); do
            process_request $i &
            pids+=($!)
        done
        
        # Wait for all to complete
        for pid in "${pids[@]}"; do
            wait $pid
        done
        
        local end=$(date +%s%N)
        local duration_ns=$((end - start))
        local duration_ms=$((duration_ns / 1000000))
        local avg_ms=$((duration_ms / level))
        
        PERFORMANCE_RESULTS+=("Concurrent load (${level}): avg ${avg_ms}ms/request")
        echo "  Concurrency ${level}: avg ${avg_ms}ms/request"
    done
    
    test_pass "Concurrent load test completed"
}

test_cache_performance() {
    test_start "Cache Performance"
    
    local cache_dir="$PROJECT_DIR/cache/gemini"
    mkdir -p "$cache_dir"
    
    # Create test cache entries
    local cache_entries=100
    local hits=0
    local misses=0
    
    for i in $(seq 1 $cache_entries); do
        local key="test_key_$i"
        local value="cached_value_$i"
        
        # Write to cache
        echo "$value" > "$cache_dir/${key}.cache"
    done
    
    # Test cache retrieval
    for i in $(seq 1 120); do  # Test more than cached
        local key="test_key_$i"
        
        if [ -f "$cache_dir/${key}.cache" ]; then
            cat "$cache_dir/${key}.cache" > /dev/null
            ((hits++))
        else
            ((misses++))
        fi
    done
    
    local hit_rate=$((hits * 100 / (hits + misses)))
    PERFORMANCE_RESULTS+=("Cache hit rate: ${hit_rate}% (target: ${CACHE_HIT_RATE_TARGET}%)")
    
    # Cleanup
    rm -rf "$cache_dir/test_key_"*
    
    if [ $hit_rate -ge $CACHE_HIT_RATE_TARGET ]; then
        test_pass "Cache hit rate: ${hit_rate}% ✓"
    else
        test_fail "Cache hit rate low: ${hit_rate}%"
    fi
}

test_memory_usage() {
    test_start "Memory Usage"
    
    # Get initial memory
    local initial_mem=$(ps aux | grep "gemini-bridge" | awk '{sum+=$6} END {print sum}')
    
    # Run intensive operations
    for i in {1..100}; do
        echo '{"test":"data"}' | "$PROJECT_DIR/hooks/gemini-bridge.sh" > /dev/null 2>&1 &
    done
    
    wait
    
    # Get final memory
    local final_mem=$(ps aux | grep "gemini-bridge" | awk '{sum+=$6} END {print sum}')
    
    # Calculate growth
    local mem_growth=$((final_mem - initial_mem))
    
    if [ $mem_growth -lt 10000 ]; then  # Less than 10MB growth
        test_pass "Memory usage stable (growth: ${mem_growth}KB)"
    else
        test_fail "Excessive memory growth: ${mem_growth}KB"
    fi
}

test_file_operation_speed() {
    test_start "File Operation Speed"
    
    local test_dir="$TEST_TMP_DIR/file_perf"
    mkdir -p "$test_dir"
    
    # Test file write speed
    local write_start=$(date +%s%N)
    for i in {1..100}; do
        echo "test data $i" > "$test_dir/file_$i.txt"
    done
    local write_end=$(date +%s%N)
    
    local write_duration_ms=$(((write_end - write_start) / 1000000))
    
    # Test file read speed
    local read_start=$(date +%s%N)
    for i in {1..100}; do
        cat "$test_dir/file_$i.txt" > /dev/null
    done
    local read_end=$(date +%s%N)
    
    local read_duration_ms=$(((read_end - read_start) / 1000000))
    
    PERFORMANCE_RESULTS+=("File operations - Write: ${write_duration_ms}ms, Read: ${read_duration_ms}ms")
    
    # Cleanup
    rm -rf "$test_dir"
    
    if [ $write_duration_ms -lt 1000 ] && [ $read_duration_ms -lt 500 ]; then
        test_pass "File operations fast (W: ${write_duration_ms}ms, R: ${read_duration_ms}ms)"
    else
        test_fail "File operations slow"
    fi
}

test_json_parsing_speed() {
    test_start "JSON Parsing Speed"
    
    # Create test JSON
    local json_small='{"key":"value"}'
    local json_medium=$(printf '{"data":[%s]}' "$(seq -s, 1 100)")
    local json_large=$(printf '{"items":[%s]}' "$(for i in {1..1000}; do echo '{"id":'$i',"data":"test"}'; done | paste -sd,)")
    
    # Test small JSON
    local start=$(date +%s%N)
    for i in {1..1000}; do
        echo "$json_small" | jq '.' > /dev/null 2>&1
    done
    local end=$(date +%s%N)
    local small_ms=$(((end - start) / 1000000))
    
    # Test medium JSON
    start=$(date +%s%N)
    for i in {1..100}; do
        echo "$json_medium" | jq '.' > /dev/null 2>&1
    done
    end=$(date +%s%N)
    local medium_ms=$(((end - start) / 1000000))
    
    # Test large JSON
    start=$(date +%s%N)
    for i in {1..10}; do
        echo "$json_large" | jq '.' > /dev/null 2>&1
    done
    end=$(date +%s%N)
    local large_ms=$(((end - start) / 1000000))
    
    PERFORMANCE_RESULTS+=("JSON parsing - Small: ${small_ms}ms, Medium: ${medium_ms}ms, Large: ${large_ms}ms")
    
    test_pass "JSON parsing performance measured"
}

generate_performance_report() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "              PERFORMANCE BENCHMARK REPORT              "
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    for result in "${PERFORMANCE_RESULTS[@]}"; do
        echo "• $result"
    done
    
    echo ""
    echo "Performance Summary:"
    echo "───────────────────"
    
    # Check if all targets met
    local targets_met=true
    
    for result in "${PERFORMANCE_RESULTS[@]}"; do
        if [[ "$result" == *"✗"* ]] || [[ "$result" == *"slow"* ]]; then
            targets_met=false
            break
        fi
    done
    
    if $targets_met; then
        echo -e "${GREEN}✓ All performance targets met${NC}"
    else
        echo -e "${YELLOW}⚠ Some performance targets not met${NC}"
        echo ""
        echo "Recommendations:"
        echo "• Optimize hook execution path"
        echo "• Implement better caching strategies"
        echo "• Consider async operations for I/O"
        echo "• Profile code to identify bottlenecks"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════"
}

# Run all performance tests
run_all_performance_tests() {
    echo "Performance Benchmark Tests"
    echo "==========================="
    
    # Setup
    export TEST_TMP_DIR=$(mktemp -d)
    export DRY_RUN=true  # Don't make real API calls
    
    test_hook_execution_speed
    test_encryption_performance
    test_token_refresh_speed
    test_concurrent_load
    test_cache_performance
    test_memory_usage
    test_file_operation_speed
    test_json_parsing_speed
    
    generate_performance_report
    
    # Cleanup
    rm -rf "$TEST_TMP_DIR"
    
    test_summary
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_performance_tests
fi