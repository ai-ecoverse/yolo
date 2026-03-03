#!/usr/bin/env bash

# YOLO Installer
# Installs the yolo wrapper to ~/.local/bin/yolo
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ai-ecoverse/yolo/main/install.sh | sh
#   OR
#   ./install.sh
#
# Copyright 2025 Lars Trieloff
# Licensed under the Apache License, Version 2.0

set -euo pipefail

VERSION="1.0.0"

# Installation directories
INSTALL_DIR="$HOME/.local/bin"
WRAPPER_NAME="yolo"
WRAPPER_PATH="$INSTALL_DIR/$WRAPPER_NAME"

# GitHub repository information
REPO_OWNER="trieloff"
REPO_NAME="yolo"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"
RAW_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if stdout is a terminal
if [[ -t 1 ]]; then
    USE_COLOR=true
else
    USE_COLOR=false
fi

# Print colored output
print_error() {
    if [[ "$USE_COLOR" == "true" ]]; then
        echo -e "${RED}✗ $*${NC}" >&2
    else
        echo "✗ $*" >&2
    fi
}

print_success() {
    if [[ "$USE_COLOR" == "true" ]]; then
        echo -e "${GREEN}✓ $*${NC}"
    else
        echo "✓ $*"
    fi
}

print_warning() {
    if [[ "$USE_COLOR" == "true" ]]; then
        echo -e "${YELLOW}⚠ $*${NC}"
    else
        echo "⚠ $*"
    fi
}

print_info() {
    if [[ "$USE_COLOR" == "true" ]]; then
        echo -e "${BLUE}ℹ $*${NC}"
    else
        echo "ℹ $*"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if git is installed (recommended but not required)
check_git() {
    if ! command_exists git; then
        print_warning "Git is not installed"
        print_info "Git is recommended for worktree functionality"
        return 1
    fi
    print_success "Git is installed"
    return 0
}

# Detect the user's shell
detect_shell() {
    local shell_name
    shell_name="$(basename "$SHELL")"
    echo "$shell_name"
}

# Get the shell configuration file
get_shell_config() {
    local shell_name="$1"
    case "$shell_name" in
        bash)
            if [[ -f "$HOME/.bashrc" ]]; then
                echo "$HOME/.bashrc"
            else
                echo "$HOME/.bash_profile"
            fi
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        elvish)
            echo "$HOME/.config/elvish/rc.elv"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check if directory is in PATH
is_in_path() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Ensure install directory exists
ensure_install_dir() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_info "Creating directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        if [[ ! -d "$INSTALL_DIR" ]]; then
            print_error "Failed to create directory: $INSTALL_DIR"
            exit 1
        fi
    fi

    if [[ ! -w "$INSTALL_DIR" ]]; then
        print_error "Directory is not writable: $INSTALL_DIR"
        exit 1
    fi

    print_success "Install directory ready: $INSTALL_DIR"
}

# Download a file from GitHub
download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -q "$url" -O "$output"
    else
        print_error "Neither curl nor wget is available"
        print_info "Please install curl or wget and try again"
        exit 1
    fi
}

# Install the wrapper
install_wrapper() {
    print_info "Installing yolo wrapper to $WRAPPER_PATH"

    # Check if we're running from the repository directory
    if [[ -f "./executable_yolo" ]]; then
        print_info "Found local executable_yolo, using it"
        cp "./executable_yolo" "$WRAPPER_PATH"
    else
        print_info "Downloading executable_yolo from GitHub"
        download_file "$RAW_URL/executable_yolo" "$WRAPPER_PATH"
    fi

    # Make it executable
    chmod +x "$WRAPPER_PATH"

    # Verify the installation
    if [[ -x "$WRAPPER_PATH" ]]; then
        print_success "Installed yolo to $WRAPPER_PATH"
    else
        print_error "Installation failed - wrapper is not executable"
        exit 1
    fi
}

# Add directory to PATH in shell config
add_to_path() {
    local shell_name="$1"
    local config_file
    config_file="$(get_shell_config "$shell_name")"

    if [[ -z "$config_file" ]]; then
        print_warning "Could not determine config file for shell: $shell_name"
        return 1
    fi

    # Create config file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        touch "$config_file"
    fi

    # Check if PATH modification already exists
    if grep -q "$INSTALL_DIR" "$config_file" 2>/dev/null; then
        print_info "PATH already configured in $config_file"
        return 0
    fi

    # Add to PATH based on shell
    case "$shell_name" in
        bash|zsh)
            echo "" >> "$config_file"
            echo "# Added by yolo installer" >> "$config_file"
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$config_file"
            ;;
        fish)
            mkdir -p "$(dirname "$config_file")"
            echo "" >> "$config_file"
            echo "# Added by yolo installer" >> "$config_file"
            echo "set -gx PATH $INSTALL_DIR \$PATH" >> "$config_file"
            ;;
        elvish)
            mkdir -p "$(dirname "$config_file")"
            echo "" >> "$config_file"
            echo "# Added by yolo installer" >> "$config_file"
            echo "set paths = [$INSTALL_DIR \$@paths]" >> "$config_file"
            ;;
        *)
            return 1
            ;;
    esac

    print_success "Added $INSTALL_DIR to PATH in $config_file"
    return 0
}

# Main installation function
main() {
    echo ""
    print_info "YOLO Installer v$VERSION"
    echo ""

    # Check prerequisites
    check_git || true

    # Ensure install directory exists
    ensure_install_dir

    # Install the wrapper
    install_wrapper

    # Check if install directory is in PATH
    if is_in_path "$INSTALL_DIR"; then
        print_success "$INSTALL_DIR is already in PATH"
    else
        print_warning "$INSTALL_DIR is not in PATH"

        # Detect shell and add to PATH
        local shell_name
        shell_name="$(detect_shell)"
        print_info "Detected shell: $shell_name"

        if add_to_path "$shell_name"; then
            print_success "Updated shell configuration"
            print_warning "Please restart your shell or run:"
            echo ""
            case "$shell_name" in
                bash)
                    echo "    source ~/.bashrc"
                    ;;
                zsh)
                    echo "    source ~/.zshrc"
                    ;;
                fish)
                    echo "    source ~/.config/fish/config.fish"
                    ;;
                elvish)
                    echo "    source ~/.config/elvish/rc.elv"
                    ;;
            esac
            echo ""
        else
            print_warning "Could not automatically update PATH"
            print_info "Please add the following to your shell configuration:"
            echo ""
            echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
            echo ""
        fi
    fi

    # Test the installation
    echo ""
    if command_exists yolo; then
        print_success "Installation successful! 🎉"
        echo ""
        print_info "Try it out:"
        echo "    yolo --help"
        echo "    yolo claude"
        echo "    yolo -w claude \"fix all bugs\""
    else
        print_warning "Installation complete, but 'yolo' command not found in PATH"
        print_info "You may need to restart your shell"
    fi

    echo ""
    print_info "For more information, visit: $REPO_URL"
    echo ""
}

# Run main function
main "$@"
