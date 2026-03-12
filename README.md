![YOLO - AI CLI Wrapper with Worktree Isolation](hero-banner.jpg)

# YOLO - AI CLI Tool Wrapper with Worktree Support

[![25% Vibe_Coded](https://img.shields.io/badge/25%25-Vibe_Coded-ff69b4?style=for-the-badge&logo=claude&logoColor=white)](https://github.com/ai-ecoverse/vibe-coded-badge-action)

> "You Only Launch Once... but in an isolated git worktree!"

YOLO is a command-line wrapper for AI coding assistants that automatically adds the appropriate bypass/danger flags and optionally creates isolated git worktrees for agent sessions.

Part of the **[AI Ecoverse](https://github.com/ai-ecoverse/.github)** - a comprehensive ecosystem of tools for AI-assisted development:
- [ai-aligned-git](https://github.com/ai-ecoverse/ai-aligned-git) - Git wrapper for safe AI commit practices
- [ai-aligned-gh](https://github.com/ai-ecoverse/ai-aligned-gh) - GitHub CLI wrapper for proper AI attribution
- **yolo** - AI CLI launcher with worktree isolation (this project)
- [vibe-coded-badge-action](https://github.com/ai-ecoverse/vibe-coded-badge-action) - Badge showing AI-generated code percentage
- [gh-workflow-peek](https://github.com/ai-ecoverse/gh-workflow-peek) - Smarter GitHub Actions log filtering
- [upskill](https://github.com/ai-ecoverse/gh-upskill) - Install Claude/Agent skills from other repositories
- [as-a-bot](https://github.com/ai-ecoverse/as-a-bot) - GitHub App token broker for proper AI attribution

## Features

- 🚀 **Quick Launch**: Simple wrapper to launch AI tools with one command
- 🎯 **Smart Flags**: Automatically adds appropriate bypass flags for each AI tool
- 🎲 **Full YOLO Mode**: Run without arguments to randomly select an installed agent
- 🎭 **Multi-Agent Mode**: Launch multiple agents in parallel with split panes
- 📝 **Editor Mode**: Compose complex prompts in your preferred editor
- 🪟 **Ghostty Support**: Native split pane support for Ghostty terminal
- 🌳 **Worktree Isolation**: Optional `-w` flag creates isolated git worktrees
- 🔒 **Safe Experimentation**: Work in isolated environments without affecting main codebase
- 🧹 **Clean History**: Separate branches for each agent session
- 🧽 **Mop Command**: Clean up all worktrees, branches, and processes with one command
- 🛠️ **Shell Agnostic**: Works in bash, zsh, fish, elvish, and more

## Why YOLO?

AI coding assistants often require various "bypass" or "danger" flags to operate without constant permission prompts. YOLO makes this easier by:

1. **Remembering the flags** - No need to memorize `--dangerously-skip-permissions` or `--allow-all-tools`
2. **Creating safe workspaces** - Use `-w` to experiment in isolated git worktrees
3. **Organizing experiments** - Each session gets its own timestamped branch in `.yolo/`
4. **Easy cleanup** - Use `yolo --mop` to clean up all worktrees and branches

## Kimi CLI Detection

YOLO now automatically detects when it's running inside Kimi CLI and provides enhanced integration:

- **Automatic Detection**: YOLO recognizes when it's launched from within Kimi CLI by analyzing the process tree
- **Enhanced Messages**: Get informative feedback when running in Kimi CLI environment
- **Seamless Integration**: No configuration needed - detection works automatically

When YOLO detects it's running inside Kimi CLI, you'll see:
```
Detected Kimi CLI environment! YOLO is running inside Kimi CLI - enhanced integration enabled
```

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ai-ecoverse/yolo/main/install.sh | sh
```

### Manual Install

```bash
git clone https://github.com/ai-ecoverse/yolo.git
cd yolo
./install.sh
```

### What It Does

The installer:
1. Creates `~/.local/bin` directory (if needed)
2. Copies `executable_yolo` to `~/.local/bin/yolo`
3. Adds `~/.local/bin` to your PATH (if needed)
4. Makes the script executable

After installation, restart your shell or run:
```bash
source ~/.bashrc  # or ~/.zshrc, ~/.config/fish/config.fish, etc.
```

## Usage

### Full YOLO Mode

Can't decide which AI assistant to use? Let YOLO decide for you!

```bash
# Randomly select from all installed coding agents
yolo

# Full YOLO in a new worktree
yolo -w

# See what would happen without actually running
yolo --dry-run
```

When you run `yolo` without specifying a command, it scans your system for all installed supported coding agents (codex, claude, copilot, droid, amp, cursor-agent, opencode, gemini, qwen, kimi, crush, aider, goose) and picks one at random. You only live yolo - even choosing your AI assistant is too much commitment!

### Basic Usage

```bash
# Launch Claude Code with --dangerously-skip-permissions
yolo claude

# Launch Codex with --dangerously-bypass-approvals-and-sandbox
yolo codex "implement feature X"

# Launch Copilot with --allow-all-tools --allow-all-paths
yolo copilot chat
```

### Editor Mode

Compose longer, more complex prompts using your preferred editor:

```bash
# Launch $EDITOR to compose prompt for a single agent
yolo -e claude

# Compose prompt in editor for multiple agents
yolo -e codex,claude,gemini

# Works in full YOLO mode too
yolo -e

# Combine with worktree mode
yolo -e -w claude
```

When you use `-e` or `--editor`, YOLO launches the editor specified in your `$EDITOR` environment variable (defaults to `vi`). After you save and close the editor, the content becomes the prompt for your agent(s). This works in:
- **Single-agent mode**: Prompt passed to one agent
- **Multi-agent mode**: Same prompt sent to all agents in parallel
- **Full YOLO mode**: Prompt sent to randomly selected agent

Lines starting with `#` in the editor are treated as comments and removed from the final prompt.

### Multi-Agent Mode

Launch multiple AI agents in parallel, each in its own split pane and isolated worktree:

```bash
# Launch 3 agents in parallel with the same prompt
yolo codex,claude,gemini "build a devcontainer and run tests"

# Launch up to 12 agents at once (example with 9)
yolo codex,claude,cursor-agent,opencode,amp,droid,copilot,gemini,kimi "say your name"

# Each agent gets:
# - Its own split pane in Ghostty
# - Its own isolated git worktree in .yolo/<agent>-N
# - The same prompt/task
```

**Multiplexer Support:**
- **Ghostty**: Native split support with optimal grid layouts (2-12 agents)

Multi-agent mode requires Ghostty terminal with AppleScript support. Splits are automatically cleaned up when agents exit.

### Worktree Mode

Create an isolated git worktree before launching the AI tool:

```bash
# Create worktree in .yolo/claude-1 with branch claude-1
# Prompts for cleanup when command finishes
yolo -w claude "refactor the entire codebase"

# Automatically clean up worktree after command completes
yolo -w -c claude "quick experiment"

# Preserve worktree after command completes (no prompt)
yolo -w -nc claude "keep this work"

# Work in isolation - changes are in the worktree
# Original code remains untouched
```

**What happens in worktree mode:**
1. Checks you're in a git repository
2. Creates `.yolo/` directory
3. Creates a new branch: `<command>-N` (where N is the lowest available number)
4. Creates worktree at `.yolo/<command>-N`
5. Changes to the worktree directory
6. Launches the AI tool
7. After completion:
   - With `-c/--clean`: Automatically removes worktree and branch
   - With `-nc/--no-clean`: Preserves worktree without prompting
   - Without flags: Prompts user whether to clean up

### Cleanup Mode

Clean up all YOLO worktrees, branches, and processes at once:

```bash
# Mop up everything
yolo --mop  # or yolo -m

# What it does:
# 1. Finds and kills processes running in .yolo directories (asks for confirmation)
# 2. Removes all .yolo worktrees
# 3. Deletes all agent branches (claude-N, codex-N, etc.)
# 4. Removes empty .yolo directory
```

Use `--mop` to clean up orphaned worktrees from interrupted sessions or when you want a fresh start.

### Supported Commands

| Command | Flags Added |
|---------|-------------|
| `codex` | `--dangerously-bypass-approvals-and-sandbox` |
| `claude` | `--dangerously-skip-permissions` |
| `copilot` | `--allow-all-tools --allow-all-paths` |
| `droid` | *(no flags - prompt allowed positionally)* |
| `amp` | `--dangerously-allow-all` |
| `aider` | `--yes-always` |
| `cursor-agent` | `--force` |
| `gemini` | `--yolo` (+ `-i` when prompt present) |
| `opencode` | *(no flags)* |
| `qwen` | `--yolo` (+ `-i` when prompt present) |
| `kimi` | `--yolo` (+ `--command` when prompt present) |
| `crush` | `--yolo` (+ Ghostty injection when prompt present) |
| `goose` | *(no flags - prompts passed via stdin)* |
| *(other)* | `--yolo` |

### Examples

```bash
# Aider examples
yolo aider "add authentication middleware" # Run aider with auto-approval
yolo -w aider "implement feature" # Create worktree for aider session
yolo -e aider # Compose complex prompt in editor for aider
yolo -w -c aider "quick experiment" # Create worktree, auto-cleanup after
yolo -w -nc aider "keep this work" # Create worktree, preserve it after

# Full YOLO mode - random agent selection
yolo
yolo -w  # Random agent in a new worktree

# Basic usage
yolo claude
yolo claude "fix all the bugs"
yolo codex --help

# Goose examples
yolo goose "analyze the codebase and suggest improvements"
yolo -w goose "implement feature X"  # Create worktree for goose session
yolo -e goose  # Compose complex prompt in editor for goose
yolo -w -c goose "quick experiment"  # Create worktree, auto-cleanup after
yolo -w -nc goose "keep this work"  # Create worktree, preserve it after

# Editor mode
yolo -e claude                          # Compose prompt in editor
yolo -e codex,claude,gemini             # Editor prompt for multi-agent
yolo -e                                 # Editor + full YOLO mode

# Worktree mode
yolo -w claude                          # Prompt for cleanup
yolo -w -c codex "quick test"           # Auto-cleanup
yolo -w -nc claude "keep this"          # No cleanup
yolo --worktree codex "refactoring"     # Prompt for cleanup
yolo -e -w claude                       # Editor + worktree mode

# OpenCode (no extra flags added)
yolo opencode "build"
yolo -w opencode "run integration suite"

# Kimi (uses --yolo flag)
yolo kimi "explain this codebase"
yolo -w kimi "refactor authentication system"

# Crush (uses --yolo flag)
yolo crush "add type annotations"
yolo -w crush "implement error handling"
yolo codex,claude,crush "review this code"

# Help and version
yolo --help
yolo --version

# Dry-run mode
yolo --dry-run  # See which agent would be selected
yolo --dry-run claude "test changes"
yolo -n codex  # Short form

# Cleanup all worktrees at once
yolo --mop
```

## How It Works

### Full YOLO Mode

When you run `yolo` without specifying a command:

```bash
# You type:
yolo

# YOLO does:
# 1. Scans PATH for installed agents (codex, claude, copilot, droid, amp, cursor-agent, opencode, gemini, qwen, kimi, crush, aider, goose)
# 2. Picks one at random using $RANDOM
# 3. Adds appropriate flags for that agent
# 4. Launches it

# Example output:
# Full YOLO mode activated! Picking a random coding agent...
# Selected: claude
# [claude launches with --dangerously-skip-permissions]
```

### Flag Mapping

YOLO recognizes common AI CLI tools and adds the appropriate flags:

```bash
# You type:
yolo claude "implement feature"

# YOLO executes:
claude --dangerously-skip-permissions "implement feature"
```

### Worktree Creation

When you use `-w` or `--worktree`:

```bash
# You type:
yolo -w claude "big refactor"

# YOLO does:
# 1. Creates .yolo/ directory
# 2. Finds lowest available number (e.g., 1)
# 3. Creates branch: claude-1
# 4. Creates worktree: .yolo/claude-1
# 5. cd to worktree
# 6. Runs: claude --dangerously-skip-permissions "big refactor"
```

## Worktree Benefits

### Safe Experimentation
```bash
# Main codebase stays pristine
yolo -w claude "try a radical refactor"

# If it works: merge the branch
# If it fails: just delete the worktree
```

### Parallel Sessions
```bash
# Terminal 1: Feature work
cd ~/project
yolo -w claude "add auth system"

# Terminal 2: Bug fixing (main codebase unaffected)
cd ~/project
yolo -w claude "fix the memory leak"
```

### Clean Separation
```
your-repo/
├── .yolo/
│   ├── claude-1/   # Session 1
│   ├── claude-2/   # Session 2
│   └── codex-1/    # Session 3
└── (your main code)
```

### Cleaning Up Worktrees

YOLO can automatically clean up worktrees after command completion:

```bash
# Automatic cleanup with -c flag
yolo -w -c claude "quick experiment"    # Cleans up automatically when done

# No cleanup with -nc flag
yolo -w -nc claude "keep this work"     # Preserves worktree

# Prompt mode (default)
yolo -w claude "some work"              # Asks if you want to clean up
```

Manual cleanup if needed:

```bash
# Remove a specific worktree
git worktree remove .yolo/claude-1

# Delete the associated branch
git branch -D claude-1

# Or clean up all worktrees at once with mop
yolo --mop

# List all worktrees to see what's active
git worktree list
```

**Tip**: Add `.yolo/` to your `.gitignore` to keep worktree directories out of your repository:

```bash
echo "/.yolo/" >> .gitignore
```

## Configuration

### Environment Variables

```bash
# Enable debug output
export YOLO_DEBUG=true
yolo claude

# Override flags for specific commands
export YOLO_FLAGS_claude="--custom-flag --another-flag"
yolo claude  # Uses custom flags instead of --dangerously-skip-permissions

# For commands with hyphens, use underscores in env var names
export YOLO_FLAGS_cursor_agent="--custom-force-flag"
yolo cursor-agent  # Uses custom flags instead of --force

# Override for any command
export YOLO_FLAGS_mycommand="--special-mode"
yolo mycommand  # Uses --special-mode instead of --yolo
```

**Note**: Command names with hyphens (like `cursor-agent`) are converted to underscores in environment variable names (e.g., `YOLO_FLAGS_cursor_agent`).

### Dry-Run Mode

Preview what YOLO would execute without actually running the command:

```bash
# See what would be executed
yolo --dry-run claude "implement feature"

# Output:
# Dry-run mode - would execute:
# claude --dangerously-skip-permissions implement feature

# Combine with worktree mode
yolo -w --dry-run claude "big refactor"
```

## Uninstallation

```bash
# Remove the wrapper
rm ~/.local/bin/yolo

# Remove from PATH (edit your shell config manually)
# Remove this line from ~/.bashrc, ~/.zshrc, etc.:
# export PATH="$HOME/.local/bin:$PATH"
```

## Testing

Run the test suite:

```bash
./test.sh
```

Tests cover:
- Command existence
- Help and version flags
- Error handling
- Flag detection for each command
- Worktree creation
- Argument preservation

## Development

### Project Structure

```
ai-aligned-yolo/
├── .github/
│   └── workflows/
│       ├── test.yml          # Test workflow
│       └── shellcheck.yml    # Linting workflow
├── executable_yolo           # Main wrapper script
├── install.sh                # Installation script
├── test.sh                   # Test suite
├── README.md                 # This file
└── LICENSE                   # Apache 2.0 license
```

### Running ShellCheck

```bash
shellcheck executable_yolo install.sh test.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests (`./test.sh`)
5. Run ShellCheck
6. Submit a pull request

## Troubleshooting

### Command not found

If `yolo` is not found after installation:

1. Check PATH:
   ```bash
   echo $PATH | grep ".local/bin"
   ```

2. If not present, add manually:
   ```bash
   # bash/zsh
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc

   # fish
   set -Ux PATH $HOME/.local/bin $PATH
   ```

### Worktree creation fails

Make sure you're in a git repository:
```bash
git status
```

If you get "not in a git repository", initialize one:
```bash
git init
git add .
git commit -m "Initial commit"
```

### Command already has flags

YOLO adds flags to commands. If your command already has conflicting flags, they may clash. In that case, call the command directly without YOLO.

## Supported AI Coding Agents

YOLO works with the following AI coding assistants:

| Agent | Repository | Description |
|-------|-----------|-------------|
| **Codex** | [github.com/openai/codex](https://github.com/openai/codex) | OpenAI's lightweight coding agent for your terminal |
| **Claude Code** | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) | Anthropic's agentic coding tool with git workflow support |
| **Copilot** | [github.com/github/copilot-cli](https://github.com/github/copilot-cli) | GitHub's AI pair programmer for the command line |
| **Droid** | [docs.factory.ai](https://docs.factory.ai) | Factory AI's coding agent with specialized droids |
| **Amp** | [ampcode.com](https://ampcode.com) / [sourcegraph.com/amp](https://sourcegraph.com/amp) | Sourcegraph's frontier coding agent |
| **Cursor Agent** | [cursor.com/cli](https://cursor.com/cli) | Cursor's headless CLI agent |
| **OpenCode** | [github.com/sst/opencode](https://github.com/sst/opencode) | Open-source AI coding agent for the terminal |
| **Qwen** | [github.com/QwenLM/Qwen](https://github.com/QwenLM/Qwen) | Alibaba's state-of-the-art large language model for coding |
| **Gemini** | [github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) | Google's open-source AI agent with Gemini 2.5 Pro |
| **Kimi** | [kimi.moonshot.cn](https://kimi.moonshot.cn) | Moonshot AI's coding assistant with advanced reasoning |
| **Crush** | [charm.sh/crush](https://charm.sh/crush) | Charm's interactive CLI tool for software engineering tasks |
| **Aider** | [github.com/paul-gauthier/aider](https://github.com/paul-gauthier/aider) | AI pair programmer in your terminal |
| **Goose** | [github.com/block/goose](https://github.com/block/goose) | Block's open-source AI coding agent (Square, Cash App, Afterpay) |

## Related Projects

- [ai-aligned-git](https://github.com/ai-ecoverse/ai-aligned-git) - Constrains AI tools to safer git practices
- [ai-aligned-gh](https://github.com/ai-ecoverse/ai-aligned-gh) - Ensures proper bot attribution for GitHub operations
- [vibe-coded-badge-action](https://github.com/ai-ecoverse/vibe-coded-badge-action) - Badge that visualizes AI contributions in your repo
- [gh-workflow-peek](https://github.com/ai-ecoverse/gh-workflow-peek) - Filter and analyze GitHub Actions logs quickly

## Version History

### v1.1.0
- **Kimi CLI Detection**: Added automatic detection when running inside Kimi CLI environment
- Enhanced integration with Kimi CLI through process tree analysis
- Improved user feedback for Kimi CLI users

### v1.0.0
- Initial release with support for 10+ AI coding assistants
- Git worktree isolation for safe experimentation
- Multi-agent parallel execution mode
- Editor mode for complex prompt composition

## License

Apache License 2.0

Copyright 2025 Lars Trieloff

## Credits

Inspired by the need to quickly launch AI coding assistants without remembering arcane flag combinations, and the desire to experiment safely with git worktrees.
