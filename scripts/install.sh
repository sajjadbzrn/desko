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
SCRIPT_START="$(date +%s)"

# ── UI helpers ──────────────────────────────────────────────────────

red()     { printf "\033[31m%s\033[0m\n" "$*"; }
green()   { printf "\033[32m%s\033[0m\n" "$*"; }
blue()    { printf "\033[34m%s\033[0m\n" "$*"; }
yellow()  { printf "\033[33m%s\033[0m\n" "$*"; }
bold()    { printf "\033[1m%s\033[0m\n" "$*"; }

log() {
  ts="$(date '+%H:%M:%S')"
  printf "  [%s] %s\n" "$ts" "$*"
}

step() {
  echo ""
  bold "  ── $* ──"
  log "Starting..."
}

warn() {
  log "⚠ $*"
}

info() {
  log "$*"
}

cleanup() {
  trap '' EXIT INT TERM
  [ -n "${tmpdir:-}" ] && rm -rf "$tmpdir"
}

# ── helpers ─────────────────────────────────────────────────────────

fmt_size() {
  # Print human-readable file size (integer only, no bc/awk dependency)
  _bytes=$1
  if [ "$_bytes" -gt 1048576 ]; then
    echo "$(( _bytes / 1048576 )) MB"
  elif [ "$_bytes" -gt 1024 ]; then
    echo "$(( _bytes / 1024 )) KB"
  else
    echo "${_bytes} B"
  fi
}

# ── platform detection ──────────────────────────────────────────────

detect_platform() {
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    linux)  os="linux"  ;;
    darwin) os="macos"  ;;
    *)
      red "✗ Unsupported OS: $os"
      exit 1
      ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="x64"   ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      red "✗ Unsupported architecture: $arch"
      exit 1
      ;;
  esac

  # macOS on x64 is fine; macOS on ARM64 is fine; Linux only x64
  if [ "$os" = "linux" ] && [ "$arch" != "x64" ]; then
    red "✗ Linux builds are only available for x86_64 (x64), not $arch"
    exit 1
  fi

  echo "${os}-${arch}"
}

# ── download with progress ──────────────────────────────────────────

download() {
  _url="$1"
  _out="$2"

  if command -v curl >/dev/null 2>&1; then
    info "Downloading via curl..."
    # --progress-bar outputs to stderr (visible even when stdout is piped to sh)
    # -f   fail on HTTP errors
    # -S   show error on failure
    # -L   follow redirects
    curl -fSL --progress-bar "$_url" -o "$_out"
    return $?
  elif command -v wget >/dev/null 2>&1; then
    info "Downloading via wget..."
    # --progress=bar:force ensures progress is displayed even with non-tty
    wget --progress=bar:force "$_url" -O "$_out"
    return $?
  else
    red "✗ Neither curl nor wget found. Please install one of them and try again."
    exit 1
  fi
}

# ── shell config ────────────────────────────────────────────────────

add_to_path() {
  _dir="$1"
  _line="export PATH=\"${_dir}:\$PATH\""

  # Determine which shell config file to update
  _rc_files=""
  case "${SHELL:-}" in
    */zsh) _rc_files="${ZDOTDIR:-$HOME}/.zshrc" ;;
    */bash)
      if [ -n "${BASH_VERSION:-}" ]; then
        _rc_files="$HOME/.bashrc"
      else
        # Running under sh; check files in order
        [ -f "$HOME/.bashrc" ] && _rc_files="$HOME/.bashrc"
      fi
      ;;
  esac

  # Fallback: try common ones
  if [ -z "$_rc_files" ]; then
    for _f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
      if [ -f "$_f" ]; then
        _rc_files="$_f"
        break
      fi
    done
  fi

  if [ -z "$_rc_files" ] || [ ! -f "$_rc_files" ]; then
    _rc_files="$HOME/.profile"
  fi

  if grep -qxF "$_line" "$_rc_files" 2>/dev/null; then
    log "✓ ${_dir} already in PATH in ${_rc_files}"
    return
  fi

  printf "\n%s\n" "$_line" >> "$_rc_files"
  log "✓ Added ${_dir} to PATH in ${_rc_files}"
  echo ""
  blue "  ➜  Run 'source ${_rc_files}' or restart your terminal to use 'desko'."
}

install_desko() {
  _platform="$1"

  # GitHub release asset name
  case "$_platform" in
    linux-x64)    _asset="desko-linux-x64"     ;;
    macos-arm64)  _asset="desko-macos-arm64"   ;;
    macos-x64)    _asset="desko-macos-x64"     ;;
    *)
      red "✗ Unknown platform: $_platform"
      exit 1
      ;;
  esac

  # Build download URL
  if [ "$VERSION" = "latest" ]; then
    _url="https://github.com/${REPO}/releases/latest/download/${_asset}"
  else
    _url="https://github.com/${REPO}/releases/download/${VERSION}/${_asset}"
  fi

  info "Release URL: $_url"

  # ── download ──────────────────────────────────────────────────────
  step "Downloading desko"

  tmpdir="$(mktemp -d "/tmp/desko-install.XXXXXX")"
  trap cleanup EXIT INT TERM

  _tmpbin="${tmpdir}/desko"
  download "$_url" "$_tmpbin"

  _download_exit=$?
  if [ "$_download_exit" -ne 0 ]; then
    red "✗ Download failed with exit code $_download_exit"
    info "Possible causes:"
    info "  • No internet connection"
    info "  • The release asset '$_asset' does not exist for version '$VERSION'"
    info "  • GitHub is unreachable from your network"
    info ""
    info "Check the releases page:"
    info "  https://github.com/${REPO}/releases"
    exit 1
  fi

  # ── verify ────────────────────────────────────────────────────────
  step "Verifying download"

  if [ ! -s "$_tmpbin" ]; then
    red "✗ Download returned an empty file."
    info "The release asset may be missing or corrupt."
    info "Check: https://github.com/${REPO}/releases"
    exit 1
  fi

  # Show file size (wc -c is POSIX-compatible)
  _file_size=$(wc -c < "$_tmpbin")
  log "Downloaded $(fmt_size "$_file_size")"

  chmod +x "$_tmpbin"

  # ── install ───────────────────────────────────────────────────────
  step "Installing binary"

  info "Creating directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"

  info "Moving binary to: ${INSTALL_DIR}/${BIN_NAME}"
  mv "$_tmpbin" "${INSTALL_DIR}/${BIN_NAME}"

  log "✓ desko installed to ${INSTALL_DIR}/${BIN_NAME}"

  # ── verify installation ───────────────────────────────────────────
  step "Verifying installation"

  "${INSTALL_DIR}/${BIN_NAME}" --version 2>&1 || true

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
        red "✗ Unknown option: $1"
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

  _platform="$(detect_platform)"

  echo "  Platform: ${_platform}"
  echo "  Version:  ${VERSION}"
  echo "  Install:  ${INSTALL_DIR}"
  echo "  Repo:     ${REPO}"
  echo ""

  # ── system check ──────────────────────────────────────────────────
  step "System check"
  log "Platform: $_platform"

  install_desko "$_platform"

  # ── done ──────────────────────────────────────────────────────────
  _elapsed=$(( $(date +%s) - SCRIPT_START ))
  echo ""
  step "Installation complete"
  log "✓ desko is ready! (completed in ${_elapsed}s)"
  echo ""
  blue "  Quick start:"
  blue "    desko add \"Buy groceries\" --priority high"
  blue "    desko list"
  blue "    desko stats"
  echo ""
}

main "$@"
