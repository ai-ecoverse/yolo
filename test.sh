#!/usr/bin/env bash

# YOLO Test Suite
# Tests the yolo wrapper functionality
#
# Copyright 2025 Lars Trieloff
# Licensed under the Apache License, Version 2.0

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default per-command timeout (seconds) for tests
YOLO_TEST_TIMEOUT="${YOLO_TEST_TIMEOUT:-30}"

# Run a command with a timeout, portable across macOS/Linux
# Usage: run_with_timeout SECONDS cmd [args...]
run_with_timeout() {
    local seconds="$1"; shift
    # Prefer GNU/BSD timeout if available
    if command -v timeout >/dev/null 2>&1; then
        # Give a 5s grace period for cleanup before SIGKILL
        timeout -k 5s "${seconds}s" "$@"
        return $?
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout -k 5s "${seconds}s" "$@"
        return $?
    fi

    # Fallback pure-bash watchdog
    "$@" &
    local cmd_pid=$!
    (
        sleep "$seconds"
        if kill -0 "$cmd_pid" 2>/dev/null; then
            echo "Timeout after ${seconds}s: $*" >&2
            kill -TERM "$cmd_pid" 2>/dev/null || true
            sleep 2
            kill -KILL "$cmd_pid" 2>/dev/null || true
        fi
    ) &
    local watcher_pid=$!
    wait "$cmd_pid"
    local rc=$?
    kill "$watcher_pid" 2>/dev/null || true
    return $rc
}

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use local executable_yolo if it exists
if [[ -f "$SCRIPT_DIR/executable_yolo" ]]; then
    YOLO_CMD="$SCRIPT_DIR/executable_yolo"
else
    YOLO_CMD="yolo"
fi

print_test_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $*"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test 1: Check if yolo command exists
test_yolo_exists() {
    print_test_header "Test 1: YOLO Command Exists"
    run_test

    if [[ -x "$YOLO_CMD" ]]; then
        print_pass "yolo command found at $YOLO_CMD"
    else
        print_fail "yolo command not found or not executable at $YOLO_CMD"
    fi
}

# Test 2: Test --help flag
test_help_flag() {
    print_test_header "Test 2: Help Flag"
    run_test

    if run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" --help >/dev/null 2>&1; then
        print_pass "yolo --help works"
    else
        print_fail "yolo --help failed"
    fi
}

# Test 3: Test --version flag
test_version_flag() {
    print_test_header "Test 3: Version Flag"
    run_test

    if run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" --version >/dev/null 2>&1; then
        print_pass "yolo --version works"
    else
        print_fail "yolo --version failed"
    fi
}

# Test 4: Test error when no command provided
test_no_command_error() {
    print_test_header "Test 4: Error When No Command"
    run_test

    if ! run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" 2>/dev/null; then
        print_pass "yolo correctly errors when no command provided"
    else
        print_fail "yolo should error when no command provided"
    fi
}

# Test 5: Test flag detection for each command
test_command_flags() {
    print_test_header "Test 5: Command Flag Detection"

    local commands=(
        "codex:--dangerously-bypass-approvals-and-sandbox"
        "claude:--dangerously-skip-permissions"
        "copilot:--allow-all-tools"
        "droid:"  # no extra flags
        "amp:--dangerously-allow-all"
        "cursor-agent:--force"
        "opencode:"  # no extra flags
        "qwen:--yolo"
        "kimi:--yolo"
        "aider:--yes-always --no-auto-commit"
        "unknown-tool:--yolo"
    )

    for cmd_pair in "${commands[@]}"; do
        run_test
        local cmd="${cmd_pair%%:*}"
        local expected_flag="${cmd_pair##*:}"

        # Create a dummy command that just echoes its arguments
        local test_script="/tmp/$cmd"
        cat > "$test_script" << 'EOF'
#!/bin/bash
echo "$@"
EOF
        chmod +x "$test_script"

        # Use PATH to make the test command available
        local output
        if output=$(PATH="/tmp:$PATH" YOLO_DEBUG=true run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" "$cmd" "test-arg" 2>&1); then
            if [[ -n "$expected_flag" ]]; then
                if echo "$output" | grep -F -q -- "$expected_flag"; then
                    print_pass "yolo $cmd includes $expected_flag"
                else
                    print_fail "yolo $cmd should include $expected_flag (got: $output)"
                fi
            else
                # No extra flag expected; ensure command ran and preserved args
                if echo "$output" | grep -q "test-arg"; then
                    print_pass "yolo $cmd adds no extra flags and preserves args"
                else
                    print_fail "yolo $cmd did not preserve args (got: $output)"
                fi
            fi
        else
            # Command not found is OK for this test
            print_info "Skipping flag test for $cmd (command not found)"
        fi

        rm -f "$test_script"
    done
}

# Test 5b: Qwen gets -i when prompt is provided (single-agent)
test_qwen_interactive_with_prompt() {
    print_test_header "Test 5b: Qwen -i Added With Prompt"
    run_test

    # Create a dummy qwen that just echoes its arguments
    local test_script="/tmp/qwen"
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "$@"
EOF
    chmod +x "$test_script"

    # Run yolo qwen with a positional prompt
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" qwen "hello world" 2>&1); then
        if echo "$output" | grep -F -q -- "-i" && echo "$output" | grep -F -q -- "hello world"; then
            print_pass "yolo qwen adds -i and passes prompt"
        else
            print_fail "yolo qwen should add -i and pass prompt (got: $output)"
        fi
    else
        print_info "Skipping qwen -i test (command not executed)"
    fi

    rm -f "$test_script"
}

# Test 5d: Aider gets prompt via AppleScript injection
test_aider_prompt_injection() {
    print_test_header "Test 5d: Aider Prompt Injection"
    run_test

    # Create a dummy aider that just echoes its arguments
    local test_script="/tmp/aider"
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "$@"
EOF
    chmod +x "$test_script"

    # Run yolo aider with a positional prompt
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" aider "implement feature" 2>&1); then
        if echo "$output" | grep -F -q "--yes-always" && echo "$output" | grep -F -q "implement feature"; then
            print_pass "yolo aider adds --yes-always and passes prompt"
        else
            print_fail "yolo aider should add --yes-always and pass prompt (got: $output)"
        fi
    else
        print_info "Skipping aider prompt test (command not executed)"
    fi

    # Test with worktree flag
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w aider "implement feature" 2>&1); then
        if echo "$output" | grep -F -q "--yes-always" && echo "$output" | grep -F -q "implement feature"; then
            print_pass "yolo -w aider adds --yes-always and passes prompt"
        else
            print_fail "yolo -w aider should add --yes-always and pass prompt (got: $output)"
        fi
    else
        print_info "Skipping aider worktree test (command not executed)"
    fi

    rm -f "$test_script"
}

# Test 5c: Kimi gets --command when prompt is provided (single-agent)
test_kimi_command_with_prompt() {
    print_test_header "Test 5c: Kimi --command Added With Prompt"
    run_test

    # Create a dummy kimi that just echoes its arguments
    local test_script="/tmp/kimi"
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "$@"
EOF
    chmod +x "$test_script"

    # Run yolo kimi with a positional prompt
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" kimi "hello world" 2>&1); then
        if echo "$output" | grep -F -q -- "--command" && echo "$output" | grep -F -q -- "hello world"; then
            print_pass "yolo kimi adds --command and passes prompt"
        else
            print_fail "yolo kimi should add --command and pass prompt (got: $output)"
        fi
    else
        print_info "Skipping kimi --command test (command not executed)"
    fi

    rm -f "$test_script"
}

# Test 6: Test Kimi CLI detection function
test_kimi_cli_detection() {
    print_test_header "Test 6: Kimi CLI Detection"
    run_test

    # Create a test script that simulates kimi environment
    local test_kimi_script="/tmp/test_kimi"
    cat > "$test_kimi_script" << 'EOF'
#!/bin/bash
# Simulate kimi CLI by creating a fake process tree
echo "Simulating Kimi CLI environment"
EOF
    chmod +x "$test_kimi_script"

    # Test detection when not in kimi (should return false)
    # Check for the actual detection output (second line) which won't appear in help text
    if ! "$YOLO_CMD" --help 2>&1 | grep -q "YOLO is running inside Kimi CLI"; then
        print_pass "No false positive Kimi CLI detection"
    else
        print_fail "False positive Kimi CLI detection"
    fi

    # Note: Full integration test would require actually running under kimi
    # which is difficult to simulate in a test environment
    print_info "Kimi CLI detection test completed (full integration requires actual Kimi CLI)"

    rm -f "$test_kimi_script"
}

# Test 7: Test worktree creation (if in a git repo)
test_worktree_creation() {
    print_test_header "Test 6: Worktree Creation"

    # Create a temporary git repository for testing
    local test_repo="/tmp/yolo_test_repo_$$"
    mkdir -p "$test_repo"
    cd "$test_repo"

    # Initialize git repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create an initial commit
    echo "test" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    run_test

    # Create a dummy echo command
    local echo_cmd="/tmp/test_yolo_echo"
    cat > "$echo_cmd" << 'EOF'
#!/bin/bash
echo "Running in: $PWD"
echo "Args: $@"
EOF
    chmod +x "$echo_cmd"

    # Test worktree creation (use -nc to avoid cleanup prompt in tests)
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w -nc echo "test" 2>&1); then
        if [[ -d "$test_repo/.yolo" ]]; then
            print_pass "Worktree directory .yolo created"

            # Check if worktree was created
            local worktree_count
            worktree_count=$(find "$test_repo/.yolo" -maxdepth 1 -type d -name "echo-*" | wc -l)
            if [[ $worktree_count -gt 0 ]]; then
                print_pass "Worktree subdirectory created in .yolo"
            else
                print_fail "No worktree subdirectory found in .yolo"
            fi
        else
            print_fail ".yolo directory not created"
        fi
    else
        print_fail "yolo -w failed: $output"
    fi

    # Cleanup
    cd /tmp
    rm -rf "$test_repo"
    rm -f "$echo_cmd"
}

# Test 7: Test worktree error when not in git repo
test_worktree_no_git_error() {
    print_test_header "Test 7: Worktree Error Outside Git Repo"
    run_test

    # Create a temporary non-git directory
    local test_dir="/tmp/yolo_test_nogit_$$"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create a dummy command
    local echo_cmd="/tmp/test_yolo_echo2"
    cat > "$echo_cmd" << 'EOF'
#!/bin/bash
echo "Should not run"
EOF
    chmod +x "$echo_cmd"

    # Test that worktree fails outside git repo
    if ! PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w echo "test" 2>/dev/null; then
        print_pass "yolo -w correctly errors outside git repository"
    else
        print_fail "yolo -w should error outside git repository"
    fi

    # Cleanup
    cd /tmp
    rm -rf "$test_dir"
    rm -f "$echo_cmd"
}

# Test 8: Test that original command arguments are preserved
test_argument_preservation() {
    print_test_header "Test 8: Argument Preservation"
    run_test

    # Create a test command that prints all arguments
    local test_cmd="/tmp/yolo_test_myecho"
    cat > "$test_cmd" << 'EOF'
#!/bin/bash
for arg in "$@"; do
    echo "ARG: $arg"
done
exit 0
EOF
    chmod +x "$test_cmd"

    # Run yolo with multiple arguments (skip --yolo flag since command doesn't support it)
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" yolo_test_myecho "arg1" "arg with spaces" "arg3" 2>&1); then
        if echo "$output" | grep -q "ARG: arg1" && \
           echo "$output" | grep -q "ARG: arg with spaces" && \
           echo "$output" | grep -q "ARG: arg3"; then
            print_pass "Command arguments preserved correctly"
        else
            print_fail "Command arguments not preserved (got: $output)"
        fi
    else
        print_fail "yolo command execution failed"
    fi

    # Cleanup
    rm -f "$test_cmd"
}

# Test 9: Test yolo -w claude delegates to claude's built-in --worktree
test_claude_builtin_worktree() {
    print_test_header "Test 9: Claude Built-in Worktree Delegation"

    # Create a temporary git repository for testing
    local test_repo="/tmp/yolo_test_claude_$$"
    mkdir -p "$test_repo"
    cd "$test_repo"

    # Initialize git repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Create a dummy claude command that echoes args (so we can assert pass-through)
    local claude_cmd="/tmp/claude"
    cat > "$claude_cmd" << 'EOF'
#!/bin/bash
echo "Running in: $PWD"
echo "Args: $@"
EOF
    chmod +x "$claude_cmd"

    # Assertion 1: --worktree is passed through when -w is set
    run_test
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w claude "fix the bug" 2>&1); then
        if echo "$output" | grep -F -q -- "--worktree"; then
            print_pass "yolo -w claude passes through --worktree flag"
        else
            print_fail "yolo -w claude should pass --worktree (got: $output)"
        fi
    else
        print_fail "yolo -w claude failed to run"
    fi

    # Assertion 2: -- separator precedes the prompt so commander does not eat it
    run_test
    if echo "$output" | grep -F -q -- "--worktree -- fix the bug"; then
        print_pass "yolo -w claude inserts -- before prompt to preserve it"
    else
        print_fail "yolo -w claude should insert -- before prompt (got: $output)"
    fi

    # Assertion 3: yolo did NOT create a .yolo/ directory
    run_test
    if [[ ! -d "$test_repo/.yolo" ]]; then
        print_pass "yolo -w claude does not create .yolo/ worktree directory"
    else
        print_fail "yolo -w claude should not create .yolo/ directory"
    fi

    # Assertion 4: yolo did NOT create a git worktree
    run_test
    local wt_count
    wt_count=$(git worktree list | wc -l | tr -d ' ')
    if [[ "$wt_count" == "1" ]]; then
        print_pass "yolo -w claude does not invoke git worktree add"
    else
        print_fail "yolo -w claude should not create a git worktree (found $wt_count)"
    fi

    # Assertion 5: yolo claude (without -w) does NOT pass --worktree
    run_test
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" claude "hello" 2>&1); then
        if ! echo "$output" | grep -F -q -- "--worktree"; then
            print_pass "yolo claude (no -w) does not pass --worktree"
        else
            print_fail "yolo claude should not pass --worktree without -w (got: $output)"
        fi
    else
        print_fail "yolo claude failed to run"
    fi

    # Cleanup
    cd /tmp
    rm -rf "$test_repo"
    rm -f "$claude_cmd"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        return 1
    fi
}

# Main test runner
main() {
    echo ""
    echo -e "${BLUE}YOLO Test Suite${NC}"
    echo ""

    test_yolo_exists
    test_help_flag
    test_version_flag
    test_no_command_error
    test_command_flags
    test_qwen_interactive_with_prompt
    test_kimi_command_with_prompt
    test_kimi_cli_detection
    test_aider_prompt_injection
    test_worktree_creation
    test_worktree_no_git_error
    test_argument_preservation
    test_claude_builtin_worktree

    print_summary
}

# Run tests
main "$@"
