#!/bin/sh
#
# desko — Installer for macOS & Linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.sh | sh -s -- --version v0.1.0
#   curl -fsSL https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.sh | sh -s -- --to /usr/local/bin
#

set -u

REPO="sajjadbzrn/desko"
INSTALL_DIR="${HOME}/.desko/bin"
VERSION="latest"
BIN_NAME="desko"

# ── helpers ──────────────────────────────────────────────────────────

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
blue()  { printf "\033[34m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

cleanup() {
  trap '' EXIT INT TERM
  [ -n "${tmpdir:-}" ] && rm -rf "$tmpdir"
}

# ── platform detection ──────────────────────────────────────────────

detect_platform() {
  local os arch

  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux)  os="linux"  ;;
    darwin) os="macos"  ;;
    *)
      red "Unsupported OS: $os"
      exit 1
      ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="x64"   ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      red "Unsupported architecture: $arch"
      exit 1
      ;;
  esac

  # macOS on x64 is fine; macOS on ARM64 is fine; Linux only x64
  if [ "$os" = "linux" ] && [ "$arch" != "x64" ]; then
    red "Linux builds are only available for x86_64 (x64), not $arch"
    exit 1
  fi

  echo "${os}-${arch}"
}

# ── download helpers ────────────────────────────────────────────────

download() {
  local url="$1" out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$out"
  else
    red "Neither curl nor wget found. Please install one of them and try again."
    exit 1
  fi
}

# ── shell config ────────────────────────────────────────────────────

add_to_path() {
  local dir="$1"
  local line
  line="export PATH=\"${dir}:\$PATH\""

  # Determine which shell config file to update
  local rc_files=""
  case "${SHELL:-}" in
    */zsh) rc_files="${ZDOTDIR:-$HOME}/.zshrc" ;;
    */bash)
      if [ -n "${BASH_VERSION:-}" ]; then
        rc_files="$HOME/.bashrc"
      else
        # Running under sh; check files in order
        [ -f "$HOME/.bashrc" ] && rc_files="$HOME/.bashrc"
      fi
      ;;
  esac

  # Fallback: try common ones
  if [ -z "$rc_files" ]; then
    for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
      if [ -f "$f" ]; then
        rc_files="$f"
        break
      fi
    done
  fi

  if [ -z "$rc_files" ] || [ ! -f "$rc_files" ]; then
    rc_files="$HOME/.profile"
  fi

  if grep -qxF "$line" "$rc_files" 2>/dev/null; then
    green "✓ ${dir} already in PATH in ${rc_files}"
    return
  fi

  printf "\n%s\n" "$line" >> "$rc_files"
  green "✓ Added ${dir} to PATH in ${rc_files}"
  echo ""
  blue "  ➜  Run 'source ${rc_files}' or restart your terminal to use 'desko'."
}

install_desko() {
  local platform="$1"

  # GitHub release asset name
  case "$platform" in
    linux-x64)    asset="desko-linux-x64"     ;;
    macos-arm64)  asset="desko-macos-arm64"   ;;
    macos-x64)    asset="desko-macos-x64"     ;;
    *)
      red "Unknown platform: $platform"
      exit 1
      ;;
  esac

  # Build download URL
  if [ "$VERSION" = "latest" ]; then
    url="https://github.com/${REPO}/releases/latest/download/${asset}"
  else
    url="https://github.com/${REPO}/releases/download/${VERSION}/${asset}"
  fi

  echo "↓ Downloading desko for ${platform}..."

  tmpdir="$(mktemp -d "/tmp/desko-install.XXXXXX")"
  trap cleanup EXIT INT TERM

  local tmpbin="${tmpdir}/desko"
  download "$url" "$tmpbin"

  if [ ! -s "$tmpbin" ]; then
    red "✗ Download failed or returned an empty file."
    red "  Check that ${asset} exists in the ${VERSION} release at:"
    red "  https://github.com/${REPO}/releases"
    exit 1
  fi

  chmod +x "$tmpbin"

  # Create install directory
  mkdir -p "$INSTALL_DIR"

  # Move binary
  mv "$tmpbin" "${INSTALL_DIR}/${BIN_NAME}"

  green "✓ desko installed to ${INSTALL_DIR}/${BIN_NAME}"
  "${INSTALL_DIR}/${BIN_NAME}" --version

  echo ""
  add_to_path "$INSTALL_DIR"
}

# ── main ────────────────────────────────────────────────────────────

main() {
  # Parse args
  while [ $# -gt 0 ]; do
    case "$1" in
      --version)
        shift
        VERSION="$1"
        ;;
      --to)
        shift
        INSTALL_DIR="$1"
        ;;
      --help|-h)
        bold "desko — Installer"
        echo ""
        echo "Usage: install.sh [options]"
        echo ""
        echo "Options:"
        echo "  --version <tag>   Install a specific version (default: latest)"
        echo "  --to <directory>  Install to a custom directory"
        echo "  --help, -h        Show this help"
        echo ""
        echo "Examples:"
        echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/scripts/install.sh | sh"
        echo "  curl -fsSL ... | sh -s -- --version v0.1.0"
        echo "  curl -fsSL ... | sh -s -- --to /usr/local/bin"
        exit 0
        ;;
      *)
        red "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done

  echo ""
  bold "  ╔══════════════════════════════╗"
  bold "  ║     desko — Installer        ║"
  bold "  ╚══════════════════════════════╝"
  echo ""

  local platform
  platform="$(detect_platform)"
  echo "  Platform: ${platform}"
  echo "  Version:  ${VERSION}"
  echo "  Install:  ${INSTALL_DIR}"
  echo "  Repo:     ${REPO}"
  echo ""

  install_desko "$platform"

  echo ""
  green "✓ desko is ready!"
  echo ""
  blue "  Quick start:"
  blue "    desko add \"Buy groceries\" --priority high"
  blue "    desko list"
  blue "    desko stats"
  echo ""
}

main "$@"
