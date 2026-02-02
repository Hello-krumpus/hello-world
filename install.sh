#!/bin/bash
# Claude Code CLI Installer
# Usage: curl -fsSL https://claude.ai/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${CLAUDE_INSTALL_DIR:-$HOME/.claude}"
BIN_DIR="${CLAUDE_BIN_DIR:-$HOME/.local/bin}"
BASE_URL="https://github.com/anthropics/claude-code/releases/latest/download"

# Print colored output
info() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            error "Unsupported architecture: $(uname -m)"
            ;;
    esac
}

# Check for required commands
check_dependencies() {
    local missing=()

    for cmd in curl tar; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing[*]}"
    fi
}

# Download and extract Claude CLI
download_and_install() {
    local os="$1"
    local arch="$2"
    local filename="claude-code-${os}-${arch}.tar.gz"
    local download_url="${BASE_URL}/${filename}"
    local tmp_dir

    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    info "Downloading Claude CLI for ${os}-${arch}..."

    if ! curl -fsSL "$download_url" -o "${tmp_dir}/${filename}"; then
        error "Failed to download Claude CLI from ${download_url}"
    fi

    info "Extracting archive..."
    tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"

    # Create installation directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"

    # Install the binary
    info "Installing to ${INSTALL_DIR}..."
    cp -r "${tmp_dir}/claude"/* "$INSTALL_DIR/" 2>/dev/null || cp "${tmp_dir}/claude" "$INSTALL_DIR/" 2>/dev/null || cp -r "${tmp_dir}"/* "$INSTALL_DIR/"

    # Create symlink in bin directory
    ln -sf "${INSTALL_DIR}/claude" "${BIN_DIR}/claude"
    chmod +x "${BIN_DIR}/claude"

    success "Claude CLI installed successfully!"
}

# Update shell configuration
update_shell_config() {
    local shell_config=""
    local path_export="export PATH=\"\$HOME/.local/bin:\$PATH\""

    # Detect shell configuration file
    case "$SHELL" in
        */zsh)
            shell_config="$HOME/.zshrc"
            ;;
        */bash)
            if [ -f "$HOME/.bashrc" ]; then
                shell_config="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                shell_config="$HOME/.bash_profile"
            fi
            ;;
        */fish)
            shell_config="$HOME/.config/fish/config.fish"
            path_export="set -gx PATH \$HOME/.local/bin \$PATH"
            ;;
    esac

    if [ -n "$shell_config" ] && [ -f "$shell_config" ]; then
        if ! grep -q ".local/bin" "$shell_config" 2>/dev/null; then
            echo "" >> "$shell_config"
            echo "# Added by Claude CLI installer" >> "$shell_config"
            echo "$path_export" >> "$shell_config"
            info "Added ${BIN_DIR} to PATH in ${shell_config}"
        fi
    fi
}

# Verify installation
verify_installation() {
    if [ -x "${BIN_DIR}/claude" ]; then
        success "Verification passed!"
        echo ""
        info "To get started, run:"
        echo ""
        echo "  claude --help"
        echo ""

        # Check if PATH needs updating
        if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
            warn "Note: You may need to restart your terminal or run:"
            echo ""
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
        fi
    else
        error "Installation verification failed"
    fi
}

# Main installation flow
main() {
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║       Claude Code CLI Installer       ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""

    check_dependencies

    local os
    local arch
    os=$(detect_os)
    arch=$(detect_arch)

    info "Detected: ${os} (${arch})"

    if [ "$os" = "windows" ]; then
        error "Windows is not supported by this installer. Please use: npm install -g @anthropic-ai/claude-code"
    fi

    download_and_install "$os" "$arch"
    update_shell_config
    verify_installation

    success "Installation complete!"
}

main "$@"
