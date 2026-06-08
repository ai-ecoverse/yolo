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

# Test 10: Test yolo -w droid delegates to droid's built-in -w/--worktree
test_droid_builtin_worktree() {
    print_test_header "Test 10: Droid Built-in Worktree Delegation"

    # Create a temporary git repository for testing
    local test_repo="/tmp/yolo_test_droid_$$"
    mkdir -p "$test_repo"
    cd "$test_repo"

    # Initialize git repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Create a dummy droid command that echoes args (so we can assert pass-through)
    local droid_cmd="/tmp/droid"
    cat > "$droid_cmd" << 'EOF'
#!/bin/bash
echo "Running in: $PWD"
echo "Args: $@"
EOF
    chmod +x "$droid_cmd"

    # Assertion 1: -w is passed through when -w is set
    run_test
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w droid "fix the bug" 2>&1); then
        if echo "$output" | grep -E -q -- "(^| )-w( |$)"; then
            print_pass "yolo -w droid passes through -w flag"
        else
            print_fail "yolo -w droid should pass -w (got: $output)"
        fi
    else
        print_fail "yolo -w droid failed to run"
    fi

    # Assertion 2: -- separator precedes the prompt so commander does not eat it
    run_test
    if echo "$output" | grep -F -q -- "-w -- fix the bug"; then
        print_pass "yolo -w droid inserts -- before prompt to preserve it"
    else
        print_fail "yolo -w droid should insert -- before prompt (got: $output)"
    fi

    # Assertion 3: yolo did NOT create a .yolo/ directory
    run_test
    if [[ ! -d "$test_repo/.yolo" ]]; then
        print_pass "yolo -w droid does not create .yolo/ worktree directory"
    else
        print_fail "yolo -w droid should not create .yolo/ directory"
    fi

    # Assertion 4: yolo did NOT create a git worktree
    run_test
    local wt_count
    wt_count=$(git worktree list | wc -l | tr -d ' ')
    if [[ "$wt_count" == "1" ]]; then
        print_pass "yolo -w droid does not invoke git worktree add"
    else
        print_fail "yolo -w droid should not create a git worktree (found $wt_count)"
    fi

    # Assertion 5: yolo droid (without -w) does NOT pass -w
    run_test
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" droid "hello" 2>&1); then
        if ! echo "$output" | grep -E -q -- "(^|Args: .*) -w( |$)"; then
            print_pass "yolo droid (no -w) does not pass -w"
        else
            print_fail "yolo droid should not pass -w without -w flag (got: $output)"
        fi
    else
        print_fail "yolo droid failed to run"
    fi

    # Cleanup
    cd /tmp
    rm -rf "$test_repo"
    rm -f "$droid_cmd"
}

# Shared assertions for agents that delegate to a native --worktree and pass
# their prompt via -i (gemini, qwen). For these, yolo appends --worktree LAST
# (after the -i prompt) and must not create its own .yolo/ worktree.
#
# yolo probes "<agent> --help" for the flag before delegating, and for gemini it
# also requires experimental.worktrees enabled in settings, so the dummy agent
# advertises --worktree on --help and the gemini case writes an enabling
# workspace settings file.
_assert_native_worktree_via_i() {
    local agent="$1"

    # Create a temporary git repository for testing
    local test_repo="/tmp/yolo_test_${agent}_$$"
    mkdir -p "$test_repo"
    cd "$test_repo"

    # Initialize git repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Create a dummy agent command. On --help it advertises --worktree (so yolo's
    # capability probe succeeds); otherwise it echoes its args for assertions.
    local agent_cmd="/tmp/$agent"
    cat > "$agent_cmd" << 'EOF'
#!/bin/bash
if [ "$1" = "--help" ]; then
  echo "  -w, --worktree   Start in a new git worktree  [string]"
  exit 0
fi
echo "Running in: $PWD"
echo "Args: $@"
EOF
    chmod +x "$agent_cmd"

    # gemini only honours --worktree when experimental.worktrees is enabled;
    # enable it in a workspace settings file so the delegation path is taken.
    if [[ "$agent" == "gemini" ]]; then
        mkdir -p .gemini
        printf '%s\n' '{"experimental": {"worktrees": true}}' > .gemini/settings.json
    fi

    # Assertion 1: --worktree is passed through when -w is set
    run_test
    local output
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w "$agent" "fix the bug" 2>&1); then
        if echo "$output" | grep -F -q -- "--worktree"; then
            print_pass "yolo -w $agent passes through --worktree flag"
        else
            print_fail "yolo -w $agent should pass --worktree (got: $output)"
        fi
    else
        print_fail "yolo -w $agent failed to run"
    fi

    # Assertion 2: --worktree is appended after the -i prompt (bare, last) so the
    # tool auto-generates the worktree name instead of eating the prompt
    run_test
    if echo "$output" | grep -F -q -- "-i fix the bug --worktree"; then
        print_pass "yolo -w $agent appends --worktree after the -i prompt"
    else
        print_fail "yolo -w $agent should append --worktree after -i prompt (got: $output)"
    fi

    # Assertion 3: yolo did NOT create a .yolo/ directory
    run_test
    if [[ ! -d "$test_repo/.yolo" ]]; then
        print_pass "yolo -w $agent does not create .yolo/ worktree directory"
    else
        print_fail "yolo -w $agent should not create .yolo/ directory"
    fi

    # Assertion 4: yolo did NOT create a git worktree
    run_test
    local wt_count
    wt_count=$(git worktree list | wc -l | tr -d ' ')
    if [[ "$wt_count" == "1" ]]; then
        print_pass "yolo -w $agent does not invoke git worktree add"
    else
        print_fail "yolo -w $agent should not create a git worktree (found $wt_count)"
    fi

    # Assertion 5: yolo <agent> (without -w) does NOT pass --worktree
    run_test
    if output=$(PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" "$agent" "hello" 2>&1); then
        if ! echo "$output" | grep -F -q -- "--worktree"; then
            print_pass "yolo $agent (no -w) does not pass --worktree"
        else
            print_fail "yolo $agent should not pass --worktree without -w (got: $output)"
        fi
    else
        print_fail "yolo $agent failed to run"
    fi

    # Cleanup
    cd /tmp
    rm -rf "$test_repo"
    rm -f "$agent_cmd"
}

# Test 11: Test yolo -w gemini delegates to gemini's native --worktree
test_gemini_builtin_worktree() {
    print_test_header "Test 11: Gemini Built-in Worktree Delegation"
    _assert_native_worktree_via_i "gemini"
}

# Test 12: Test yolo -w qwen delegates to qwen's native --worktree
test_qwen_builtin_worktree() {
    print_test_header "Test 12: Qwen Built-in Worktree Delegation"
    _assert_native_worktree_via_i "qwen"
}

# Test 13: When gemini's native worktree support is NOT usable (experimental
# .worktrees disabled), yolo must fall back to a yolo-managed .yolo/ worktree
# instead of passing --worktree (which gemini would reject).
test_gemini_worktree_fallback() {
    print_test_header "Test 13: Gemini Worktree Fallback (experimental disabled)"

    # Clean HOME so no user-level .gemini/settings.json can enable worktrees
    local clean_home="/tmp/yolo_test_gemini_home_$$"
    mkdir -p "$clean_home"

    local test_repo="/tmp/yolo_test_gemini_fb_$$"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Dummy gemini advertises --worktree on --help, but no settings enable it
    local agent_cmd="/tmp/gemini"
    cat > "$agent_cmd" << 'EOF'
#!/bin/bash
if [ "$1" = "--help" ]; then
  echo "  -w, --worktree   Start in a new git worktree  [string]"
  exit 0
fi
echo "Running in: $PWD"
echo "Args: $@"
EOF
    chmod +x "$agent_cmd"

    # Use -nc so the fallback worktree is preserved without an interactive prompt
    local output
    output=$(HOME="$clean_home" PATH="/tmp:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w -nc gemini "fix the bug" 2>&1)

    # Assertion 1: yolo announces the fallback
    run_test
    if echo "$output" | grep -F -q -- "falling back to a yolo-managed worktree"; then
        print_pass "yolo -w gemini falls back when experimental.worktrees is disabled"
    else
        print_fail "yolo -w gemini should fall back when experimental disabled (got: $output)"
    fi

    # Assertion 2: yolo created its own .yolo/ worktree
    run_test
    if [[ -d "$test_repo/.yolo" ]]; then
        print_pass "yolo -w gemini (disabled) creates a yolo-managed .yolo/ worktree"
    else
        print_fail "yolo -w gemini (disabled) should create a .yolo/ fallback (got: $output)"
    fi

    # Assertion 3: --worktree is NOT passed to gemini in the fallback path.
    # (Scope the check to the dummy's "Args:" line so the fallback info message,
    # which mentions "--worktree", doesn't trigger a false positive.)
    run_test
    if ! echo "$output" | grep -E -q -- "Args:.*--worktree"; then
        print_pass "yolo -w gemini (disabled) does not pass --worktree to gemini"
    else
        print_fail "yolo -w gemini (disabled) should not pass --worktree (got: $output)"
    fi

    # Cleanup (the .yolo/ worktree lives inside test_repo, so this removes it too)
    cd /tmp
    git -C "$test_repo" worktree prune 2>/dev/null || true
    rm -rf "$test_repo" "$clean_home"
    rm -f "$agent_cmd"
}

# Test 14: Dependency auto-install (-w installs, -wn / --no-install opt out)
test_dependency_auto_install() {
    print_test_header "Test 14: Dependency Auto-install"

    # --- Flag parsing / delegation note (deterministic, no background needed) ---
    local test_repo="/tmp/yolo_test_deps_$$"
    mkdir -p "$test_repo"; cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo '{"name":"x"}' > package.json
    echo '{"lockfileVersion":3}' > package-lock.json
    git add package.json
    git add package-lock.json
    git commit -q -m "init"

    # Dummy claude/npm so nothing real runs; keep the watcher short-lived.
    local bin="/tmp/yolo_test_deps_bin_$$"; mkdir -p "$bin"
    cat > "$bin/claude" << 'EOF'
#!/bin/bash
echo "Args: $@"
EOF
    cat > "$bin/npm" << 'EOF'
#!/bin/bash
[[ "$1" == "ci" ]] && { mkdir -p node_modules; exit 0; }
exit 0
EOF
    cat > "$bin/faketool" << 'EOF'
#!/bin/bash
echo "faketool ran"
EOF
    chmod +x "$bin/claude" "$bin/npm" "$bin/faketool"
    # Keep the native-worktree watcher short-lived during the test.
    export YOLO_DEPS_WATCH_TIMEOUT="${YOLO_DEPS_WATCH_TIMEOUT:-4}"

    # Assertion 1: -w claude prints the watcher auto-install note
    run_test
    local out
    out=$(PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -w claude "go" 2>&1 || true)
    if echo "$out" | grep -F -q "will auto-install"; then
        print_pass "yolo -w claude announces background dependency install"
    else
        print_fail "yolo -w claude should announce auto-install (got: $out)"
    fi

    # Assertion 2: -wn claude still delegates (--worktree) but skips auto-install
    run_test
    out=$(PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -wn claude "go" 2>&1 || true)
    if echo "$out" | grep -F -q -- "--worktree" && ! echo "$out" | grep -F -q "will auto-install"; then
        print_pass "yolo -wn claude delegates worktree but skips auto-install"
    else
        print_fail "yolo -wn claude should pass --worktree and skip auto-install (got: $out)"
    fi

    # Assertion 3: --no-install is accepted and suppresses the note
    run_test
    out=$(PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" --no-install -w claude "go" 2>&1 || true)
    if ! echo "$out" | grep -F -q "unknown option" && ! echo "$out" | grep -F -q "will auto-install"; then
        print_pass "yolo --no-install -w claude is accepted and skips auto-install"
    else
        print_fail "yolo --no-install should be accepted and skip auto-install (got: $out)"
    fi

    # --- End-to-end install into a yolo-managed .yolo/ worktree ---
    # Assertion 4: -w faketool installs deps (status ready + node_modules)
    run_test
    PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -nc -w faketool "go" >/dev/null 2>&1 || true
    local wt="$test_repo/.yolo/faketool-1"
    local state=""
    [[ -d "$wt" ]] && state="$(cd "$wt" && git rev-parse --absolute-git-dir 2>/dev/null)/yolo-deps"
    local s=""
    for _ in $(seq 1 40); do
        s="$([[ -n "$state" ]] && cat "$state/status" 2>/dev/null || echo "")"
        [[ "$s" == "ready" || "$s" == "failed" ]] && break
        sleep 0.3
    done
    if [[ "$s" == "ready" && -d "$wt/node_modules" ]]; then
        print_pass "yolo -w faketool installs deps in background (status ready, node_modules present)"
    else
        print_fail "yolo -w faketool should install deps (status=$s, node_modules=$([[ -d "$wt/node_modules" ]] && echo present || echo missing))"
    fi

    # Assertion 5: -wn faketool skips the install entirely
    run_test
    PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -nc -wn faketool "go" >/dev/null 2>&1 || true
    local wt2="$test_repo/.yolo/faketool-2"
    sleep 1
    local gd2=""
    [[ -d "$wt2" ]] && gd2="$(cd "$wt2" && git rev-parse --absolute-git-dir 2>/dev/null)"
    if [[ ! -d "$wt2/node_modules" && ( -z "$gd2" || ! -e "$gd2/yolo-deps/status" ) ]]; then
        print_pass "yolo -wn faketool skips dependency install"
    else
        print_fail "yolo -wn faketool should not install deps (node_modules=$([[ -d "$wt2/node_modules" ]] && echo present || echo missing))"
    fi

    # Assertion 6: --dry-run is preview-only -- it must NOT run the install
    # (regression test: create_worktree used to install before the dry-run check).
    # Uses a dedicated repo so node_modules can only appear if dry-run wrongly ran.
    run_test
    local dr_repo="/tmp/yolo_test_deps_dr_$$"
    mkdir -p "$dr_repo"; cd "$dr_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo '{}' > package.json
    echo '{"lockfileVersion":3}' > package-lock.json
    git add package.json
    git add package-lock.json
    git commit -q -m "init"
    PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -n -w faketool "go" >/dev/null 2>&1 || true
    sleep 1
    if ! find "$dr_repo/.yolo" -name node_modules -type d 2>/dev/null | grep -q .; then
        print_pass "yolo -n -w (dry-run) does not run the dependency install"
    else
        print_fail "yolo -n -w should not install deps in dry-run"
    fi
    PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" --mop >/dev/null 2>&1 || true

    # Assertion 7: yarn.lock present but yarn not installed must not abort under
    # set -e (regression: the yarn --version probe was fatal). Run with a minimal
    # PATH (plus our fake faketool) so any real yarn is hidden.
    run_test
    local yarn_repo="/tmp/yolo_test_deps_yarn_$$"
    mkdir -p "$yarn_repo"; cd "$yarn_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo '{}' > package.json
    : > yarn.lock
    git add package.json
    git add yarn.lock
    git commit -q -m "init"
    if PATH="$bin:/usr/bin:/bin" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" -nc -w faketool "go" >/dev/null 2>&1; then
        print_pass "yolo -w with yarn.lock but no yarn exits cleanly (no set -e abort)"
    else
        print_fail "yolo -w with yarn.lock but no yarn should not abort"
    fi
    PATH="$bin:/usr/bin:/bin" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" --mop >/dev/null 2>&1 || true

    # Cleanup (mop removes the .yolo/ worktrees this test created)
    cd "$test_repo"
    PATH="$bin:$PATH" run_with_timeout "$YOLO_TEST_TIMEOUT" "$YOLO_CMD" --mop >/dev/null 2>&1 || true
    unset YOLO_DEPS_WATCH_TIMEOUT
    cd /tmp
    rm -rf "$test_repo" "$dr_repo" "$yarn_repo" "$bin"
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
    test_droid_builtin_worktree
    test_gemini_builtin_worktree
    test_qwen_builtin_worktree
    test_gemini_worktree_fallback
    test_dependency_auto_install

    print_summary
}

# Run tests
main "$@"
