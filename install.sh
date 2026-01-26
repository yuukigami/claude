#!/bin/bash
set -e

# Claude Code CLI Installer
# Usage: curl -fsSL https://claude.ai/install.sh | bash

VERSION="latest"
PACKAGE_NAME="@anthropic-ai/claude-code"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
   _____ _                 _        _____          _
  / ____| |               | |      / ____|        | |
 | |    | | __ _ _   _  __| | ___ | |     ___   __| | ___
 | |    | |/ _` | | | |/ _` |/ _ \| |    / _ \ / _` |/ _ \
 | |____| | (_| | |_| | (_| |  __/| |___| (_) | (_| |  __/
  \_____|_|\__,_|\__,_|\__,_|\___| \_____\___/ \__,_|\___|

EOF
    echo -e "${NC}"
    echo "Claude Code CLI Installer"
    echo "========================="
    echo ""
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

detect_os() {
    OS="unknown"
    ARCH="unknown"

    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="macos";;
        MINGW*|MSYS*|CYGWIN*) OS="windows";;
        *)          OS="unknown";;
    esac

    case "$(uname -m)" in
        x86_64|amd64)   ARCH="x64";;
        arm64|aarch64)  ARCH="arm64";;
        armv7l)         ARCH="arm";;
        *)              ARCH="unknown";;
    esac

    info "Detected OS: $OS ($ARCH)"
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

get_node_version() {
    if check_command node; then
        node --version 2>/dev/null | sed 's/v//'
    else
        echo "0"
    fi
}

version_gte() {
    # Returns 0 (true) if $1 >= $2
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

install_nodejs_linux() {
    info "Installing Node.js..."

    # Try to detect package manager
    if check_command apt-get; then
        info "Using apt package manager"
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif check_command dnf; then
        info "Using dnf package manager"
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo dnf install -y nodejs
    elif check_command yum; then
        info "Using yum package manager"
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo yum install -y nodejs
    elif check_command pacman; then
        info "Using pacman package manager"
        sudo pacman -Sy --noconfirm nodejs npm
    elif check_command apk; then
        info "Using apk package manager"
        sudo apk add --no-cache nodejs npm
    else
        error "Could not detect package manager. Please install Node.js manually: https://nodejs.org/"
    fi
}

install_nodejs_macos() {
    info "Installing Node.js..."

    if check_command brew; then
        info "Using Homebrew"
        brew install node
    else
        warn "Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install node
    fi
}

install_nodejs() {
    case "$OS" in
        linux)
            install_nodejs_linux
            ;;
        macos)
            install_nodejs_macos
            ;;
        windows)
            error "Please install Node.js manually on Windows: https://nodejs.org/"
            ;;
        *)
            error "Unsupported operating system. Please install Node.js manually: https://nodejs.org/"
            ;;
    esac
}

check_nodejs() {
    local MIN_NODE_VERSION="18.0.0"

    if ! check_command node; then
        warn "Node.js is not installed"
        return 1
    fi

    local current_version
    current_version=$(get_node_version)

    if ! version_gte "$current_version" "$MIN_NODE_VERSION"; then
        warn "Node.js version $current_version is too old (minimum required: $MIN_NODE_VERSION)"
        return 1
    fi

    info "Node.js version $current_version detected"
    return 0
}

check_npm() {
    if ! check_command npm; then
        warn "npm is not installed"
        return 1
    fi

    local npm_version
    npm_version=$(npm --version 2>/dev/null)
    info "npm version $npm_version detected"
    return 0
}

install_claude_code() {
    info "Installing Claude Code CLI..."

    # Determine install method based on permissions
    if [ -w "$(npm config get prefix)/lib" ] 2>/dev/null; then
        npm install -g "$PACKAGE_NAME@$VERSION"
    else
        info "Installing globally with sudo..."
        sudo npm install -g "$PACKAGE_NAME@$VERSION"
    fi
}

verify_installation() {
    if check_command claude; then
        local installed_version
        installed_version=$(claude --version 2>/dev/null || echo "unknown")
        success "Claude Code CLI installed successfully!"
        echo ""
        echo "  Version: $installed_version"
        echo ""
        echo "  Get started by running:"
        echo ""
        echo "    claude"
        echo ""
        echo "  For help, run:"
        echo ""
        echo "    claude --help"
        echo ""
    else
        error "Installation verification failed. Please check your PATH or try reinstalling."
    fi
}

main() {
    print_banner

    detect_os

    # Check for Node.js
    if ! check_nodejs; then
        echo ""
        read -p "Would you like to install Node.js? [Y/n] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            error "Node.js is required to install Claude Code CLI"
        fi
        install_nodejs

        # Re-check after installation
        if ! check_nodejs; then
            error "Node.js installation failed. Please install manually: https://nodejs.org/"
        fi
    fi

    # Check for npm
    if ! check_npm; then
        error "npm is required but not found. Please reinstall Node.js: https://nodejs.org/"
    fi

    echo ""
    install_claude_code
    echo ""
    verify_installation
}

# Run main function
main "$@"
