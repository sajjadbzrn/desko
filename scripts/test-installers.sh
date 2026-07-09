#!/bin/sh
#
# test-installers.sh — Validate that both installer scripts parse correctly.
#
# Usage:
#   sh scripts/test-installers.sh
#
# Tests:
#   - install.sh  via sh -n  (POSIX syntax check)
#   - install.ps1 via PowerShell parser (if available)
#

set -u

errors=0

bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }

echo ""
bold "  ╔══════════════════════════════════════╗"
bold "  ║    desko — Installer Validation     ║"
bold "  ╚══════════════════════════════════════╝"
echo ""

# ── install.sh ──────────────────────────────────────────────────────

bold "  ── scripts/install.sh ──"

if command -v sh >/dev/null 2>&1; then
  if sh -n "scripts/install.sh" 2>&1; then
    green "  ✓ Shell syntax: valid"
  else
    red "  ✗ Shell syntax: INVALID"
    errors=$(( errors + 1 ))
  fi
else
  yellow "  ⚠ 'sh' not available — skipping"
fi

# ── install.ps1 ─────────────────────────────────────────────────────

echo ""
bold "  ── scripts/install.ps1 ──"

# Prefer pwsh (PowerShell Core) over powershell (Windows PowerShell)
PWSH=""
if command -v pwsh >/dev/null 2>&1; then
  PWSH="pwsh"
elif command -v powershell >/dev/null 2>&1; then
  PWSH="powershell"
fi

if [ -n "$PWSH" ]; then
  # Validate via the dedicated helper script (avoids quoting issues)
  if "$PWSH" -NoProfile -File "scripts/validate-install.ps1"; then
    :  # already printed ✓
  else
    errors=$(( errors + 1 ))
  fi
else
  yellow "  ⚠ PowerShell not available — skipping"
fi

# ── summary ─────────────────────────────────────────────────────────

echo ""
if [ "$errors" -eq 0 ]; then
  green "  ✅ All validations passed"
  exit 0
else
  red "  ❌ ${errors} validation(s) failed"
  exit 1
fi
