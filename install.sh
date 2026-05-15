#!/usr/bin/env bash
# install.sh — bootstrap digitization-tasks-helper on a Mac.
# Idempotent. Re-run after every `git pull`.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME_SHORT="$(hostname -s)"

log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Homebrew + dependencies
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  die "Homebrew not installed. Install from https://brew.sh first."
fi

log "Installing/updating dependencies from Brewfile"
brew bundle --file="$REPO_DIR/Brewfile" --no-upgrade

# ---------------------------------------------------------------------------
# 2. Pick install dir for the `digi` symlink
# ---------------------------------------------------------------------------
# Apple Silicon: brew lives in /opt/homebrew, /usr/local/bin may not be in PATH.
# Prefer ~/.local/bin (user-writable, no sudo) and warn if it's not on PATH.
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  warn "$INSTALL_DIR is not on your PATH."
  warn "Add this to ~/.zshrc:  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

ln -sfn "$REPO_DIR/bin/digi" "$INSTALL_DIR/digi"
log "Linked digi → $INSTALL_DIR/digi"

# ---------------------------------------------------------------------------
# 3. Per-machine config
# ---------------------------------------------------------------------------
MACHINE_CONFIG="$REPO_DIR/etc/machines/${HOSTNAME_SHORT}.yaml"
if [[ ! -f "$MACHINE_CONFIG" ]]; then
  log "First run on $HOSTNAME_SHORT — creating $MACHINE_CONFIG"
  cp "$REPO_DIR/etc/machines/_template.yaml" "$MACHINE_CONFIG"
  warn "Edit $MACHINE_CONFIG to set this machine's role and paths."
else
  log "Machine config exists: $MACHINE_CONFIG"
fi

# ---------------------------------------------------------------------------
# 4. Sanity check
# ---------------------------------------------------------------------------
log "Verifying digi command..."
if "$INSTALL_DIR/digi" version >/dev/null 2>&1; then
  log "✓ Install complete. Run 'digi help' to get started."
else
  warn "digi installed but failed self-check. Run 'digi help' for details."
fi
