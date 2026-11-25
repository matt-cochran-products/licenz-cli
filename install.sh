#!/bin/sh
# licenz CLI Installer
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/matt-cochran-products/licenz-cli/main/install.sh | bash
#
# Options (via environment variables):
#   INSTALL_DIR  - Installation directory (default: ~/.local/bin)
#   VERSION      - Specific version to install (default: latest)

set -e

# Configuration
REPO="matt-cochran-products/licenz-cli"
BINARY_NAME="licenz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() {
    printf "${BLUE}info:${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}success:${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}warning:${NC} %s\n" "$1"
}

error() {
    printf "${RED}error:${NC} %s\n" "$1" >&2
    exit 1
}

# Setup PATH in shell config
setup_path() {
    local install_dir="$1"
    local os=$(detect_os)

    if [ "$os" = "windows" ]; then
        setup_path_windows "$install_dir"
        return $?
    fi

    local shell_config=""
    local path_line="export PATH=\"\$PATH:${install_dir}\""

    local shell_name=$(basename "$SHELL" 2>/dev/null || echo "bash")
    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                shell_config="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                shell_config="$HOME/.bash_profile"
            elif [ -f "$HOME/.profile" ]; then
                shell_config="$HOME/.profile"
            fi
            ;;
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                shell_config="$HOME/.zshrc"
            elif [ -f "$HOME/.zprofile" ]; then
                shell_config="$HOME/.zprofile"
            fi
            ;;
        fish)
            shell_config="$HOME/.config/fish/config.fish"
            path_line="set -gx PATH \"\$PATH\" \"${install_dir}\""
            ;;
    esac

    if [ -z "$shell_config" ]; then
        for config in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
            if [ -f "$config" ]; then
                shell_config="$config"
                break
            fi
        done
    fi

    if [ -z "$shell_config" ]; then
        case "$shell_name" in
            zsh) shell_config="$HOME/.zshrc" ;;
            *)   shell_config="$HOME/.bashrc" ;;
        esac
        touch "$shell_config"
        info "Created ${shell_config}"
    fi

    if grep -q "PATH.*${install_dir}" "$shell_config" 2>/dev/null; then
        info "PATH already configured in ${shell_config}"
        return 0
    fi

    echo "" >> "$shell_config"
    echo "# Added by ${BINARY_NAME} installer" >> "$shell_config"
    echo "$path_line" >> "$shell_config"
    success "Added ${install_dir} to PATH in ${shell_config}"
    info "Run 'source ${shell_config}' or restart your terminal to use ${BINARY_NAME}"
}

# Setup PATH on Windows (Git Bash/MSYS2/WSL)
setup_path_windows() {
    local install_dir="$1"

    if [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ]; then
        local shell_config=""
        if [ -f "$HOME/.bashrc" ]; then
            shell_config="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            shell_config="$HOME/.bash_profile"
        fi

        if [ -n "$shell_config" ]; then
            if grep -q "PATH.*${install_dir}" "$shell_config" 2>/dev/null; then
                info "PATH already configured in ${shell_config}"
                return 0
            fi

            echo "" >> "$shell_config"
            echo "# Added by ${BINARY_NAME} installer" >> "$shell_config"
            echo "export PATH=\"\$PATH:${install_dir}\"" >> "$shell_config"
            success "Added ${install_dir} to PATH in ${shell_config}"
            info "Run 'source ${shell_config}' or restart your terminal"
            return 0
        fi
    fi

    if command -v powershell >/dev/null 2>&1; then
        local windows_path="$install_dir"
        if command -v cygpath >/dev/null 2>&1; then
            windows_path=$(cygpath -w "$install_dir" 2>/dev/null || echo "$install_dir")
        fi

        local current_path=$(powershell -Command "[Environment]::GetEnvironmentVariable('Path', 'User')" 2>/dev/null || echo "")

        if [ -n "$current_path" ]; then
            case ";${current_path};" in
                *";${windows_path};"*)
                    info "PATH already configured in Windows environment"
                    return 0
                    ;;
            esac

            local new_path="${current_path};${windows_path}"
            if powershell -Command "[Environment]::SetEnvironmentVariable('Path', '${new_path}', 'User')" 2>/dev/null; then
                success "Added ${install_dir} to Windows user PATH"
                warn "Please restart your terminal for changes to take effect"
                return 0
            fi
        fi
    fi

    warn "Could not automatically configure PATH on Windows"
    warn "Please add ${install_dir} to your PATH manually:"
    warn "  1. Press Win+R, type 'sysdm.cpl', press Enter"
    warn "  2. Go to Advanced tab > Environment Variables"
    warn "  3. Edit User PATH variable"
    warn "  4. Add: ${install_dir}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "darwin" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       error "Unsupported operating system: $(uname -s)" ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac
}

# Check for glibc on Linux
check_glibc() {
    if [ "$1" != "linux" ]; then
        return 0
    fi

    if [ -f /etc/alpine-release ]; then
        warn "Alpine Linux detected (uses musl, not glibc)"
        warn "The ${BINARY_NAME} binary requires glibc to run."
        warn ""
        warn "To install glibc compatibility on Alpine:"
        warn "  apk add gcompat"
        warn ""
        warn "Continuing installation, but the binary may not work..."
        return 0
    fi

    if ! command -v ldd >/dev/null 2>&1; then
        error "glibc not found. The ${BINARY_NAME} binary requires glibc to run.

Please install glibc for your distribution:
  Ubuntu/Debian: sudo apt-get update && sudo apt-get install libc6
  Fedora/RHEL:   sudo dnf install glibc
  Arch:          sudo pacman -S glibc
  Alpine:        apk add gcompat (or use a glibc-based distribution)"
    fi

    local glibc_version=$(ldd --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    if [ -z "$glibc_version" ]; then
        warn "Could not determine glibc version, but ldd is available. Proceeding..."
        return 0
    fi

    local major=$(echo "$glibc_version" | cut -d. -f1)
    local minor=$(echo "$glibc_version" | cut -d. -f2)

    if [ "$major" -lt 2 ] || ([ "$major" -eq 2 ] && [ "$minor" -lt 17 ]); then
        warn "glibc version $glibc_version detected. Version 2.17+ is recommended."
        warn "The binary may not work correctly on this system."
    else
        info "glibc version $glibc_version detected (OK)"
    fi
}

# Get target triple
get_target() {
    local os="$1"
    local arch="$2"

    case "$os" in
        linux)   echo "${arch}-unknown-linux-gnu" ;;
        darwin)  echo "${arch}-apple-darwin" ;;
        windows) echo "${arch}-pc-windows-msvc" ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    local response=""
    local http_code=""
    local tmp_file=""

    if command -v curl >/dev/null 2>&1; then
        tmp_file=$(mktemp)
        http_code=$(curl -sSL -w "%{http_code}" -o "$tmp_file" "https://api.github.com/repos/${REPO}/releases/latest" 2>&1)
        response=$(cat "$tmp_file" 2>/dev/null || echo "")
        rm -f "$tmp_file"
    elif command -v wget >/dev/null 2>&1; then
        tmp_file=$(mktemp)
        wget -q -O "$tmp_file" "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true
        response=$(cat "$tmp_file" 2>/dev/null || echo "")
        rm -f "$tmp_file"
        if echo "$response" | grep -q '"message": "Not Found"'; then
            http_code="404"
        elif echo "$response" | grep -q '"tag_name":'; then
            http_code="200"
        else
            http_code="000"
        fi
    else
        error "Neither curl nor wget found. Please install one of them."
    fi

    if [ "$http_code" = "404" ] || echo "$response" | grep -q '"message": "Not Found"'; then
        local all_releases=""
        tmp_file=$(mktemp)
        if command -v curl >/dev/null 2>&1; then
            all_releases=$(curl -sSL "https://api.github.com/repos/${REPO}/releases" 2>/dev/null || echo "")
        elif command -v wget >/dev/null 2>&1; then
            wget -q -O "$tmp_file" "https://api.github.com/repos/${REPO}/releases" 2>/dev/null || true
            all_releases=$(cat "$tmp_file" 2>/dev/null || echo "")
        fi
        rm -f "$tmp_file" 2>/dev/null || true

        if [ -n "$all_releases" ] && echo "$all_releases" | grep -q '"tag_name":'; then
            local version=$(echo "$all_releases" | grep '"tag_name":' | head -n1 | sed -E 's/.*"v([^"]+)".*/\1/')
            if [ -n "$version" ]; then
                info "Using latest available release: v${version}"
                echo "$version"
                return 0
            fi
        fi

        # No release has been published (exit status 2 tells main to say so)
        return 2
    fi

    if [ -n "$http_code" ] && [ "$http_code" != "200" ] && [ "$http_code" != "404" ] && [ "$http_code" != "000" ]; then
        error "Failed to get latest version: HTTP $http_code"
    fi

    if [ -n "$response" ]; then
        local version=$(echo "$response" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' | head -n1)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        else
            error "Failed to get latest version: Could not parse version from response"
        fi
    else
        error "Failed to get latest version: Empty response from GitHub API"
    fi
}

# Download file using curl/wget
download() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -sSfL -o "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$output" "$url"
    else
        error "Neither curl nor wget found."
    fi
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local checksum_file="$2"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -c "$checksum_file" >/dev/null 2>&1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -c "$checksum_file" >/dev/null 2>&1
    else
        warn "No checksum tool found, skipping verification"
        return 0
    fi
}

# Main installation function
main() {
    info "Installing ${BINARY_NAME}..."

    local os=$(detect_os)
    local arch=$(detect_arch)

    check_glibc "$os"

    local target=$(get_target "$os" "$arch")

    info "Detected platform: ${os} (${arch})"

    # Get version
    local version="${VERSION:-}"
    if [ -z "$version" ]; then
        local rc=0
        version=$(get_latest_version) || rc=$?
        if [ "$rc" -eq 2 ]; then
            error "no licenz release published yet. See https://github.com/${REPO}/releases, or set the VERSION env var once one exists."
        fi
    fi
    if [ -z "$version" ]; then
        error "Failed to determine latest version. Set VERSION env var to install a specific version."
    fi
    info "Installing version: v${version}"

    # Determine archive extension
    local ext="tar.gz"
    if [ "$os" = "windows" ]; then
        ext="zip"
    fi

    # Set install directory
    local install_dir="${INSTALL_DIR:-$HOME/.local/bin}"
    mkdir -p "$install_dir"

    # Create temp directory
    local tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # Download archive and checksum
    local archive_name="${BINARY_NAME}-v${version}-${target}.${ext}"
    local checksum_name="${archive_name}.sha256"
    local download_url="https://github.com/${REPO}/releases/download/v${version}/${archive_name}"

    info "Downloading from: ${download_url}"
    download "$download_url" "$tmp_dir/$archive_name"

    local checksum_url="${download_url}.sha256"
    info "Downloading checksum..."
    download "$checksum_url" "$tmp_dir/${checksum_name}" 2>/dev/null || true

    # Verify checksum if available
    cd "$tmp_dir"
    if [ -f "${checksum_name}" ]; then
        info "Verifying checksum..."
        if ! verify_checksum "$archive_name" "${checksum_name}"; then
            error "Checksum verification failed!"
        fi
        success "Checksum verified"
    else
        warn "Checksum file not available, skipping verification"
    fi

    # Extract archive
    info "Extracting..."
    if [ "$ext" = "tar.gz" ]; then
        tar -xzf "$archive_name"
    else
        unzip -q "$archive_name"
    fi

    # Install binary
    local binary_name="$BINARY_NAME"
    if [ "$os" = "windows" ]; then
        binary_name="${BINARY_NAME}.exe"
    fi

    mv "$binary_name" "$install_dir/"
    chmod +x "$install_dir/$binary_name"
    success "Installed ${BINARY_NAME} to ${install_dir}/${binary_name}"

    # Check if install_dir is in PATH
    case ":$PATH:" in
        *":$install_dir:"*)
            success "${install_dir} is already in your PATH"
            ;;
        *)
            warn "${install_dir} is not in your PATH"
            setup_path "$install_dir"
            ;;
    esac

    # Verify installation
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        success "Installation complete! Run '${BINARY_NAME} --version' to verify."
    else
        info "Installation complete! You may need to restart your shell or run:"
        info "  export PATH=\"\$PATH:${install_dir}\""
    fi
}

# Run main
main "$@"
