#!/usr/bin/env bash
# lib/common.sh — sourced by every digi-* subcommand.
# Provides logging, machine-config loading, and a few helpers.
#
# Usage in a subcommand:
#   #!/usr/bin/env bash
#   set -euo pipefail
#   source "${DIGI_LIB_DIR:?run via the digi dispatcher}/common.sh"

# ---- logging ---------------------------------------------------------------
_digi_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(_digi_ts)" "$*"; }
warn() { printf '\033[1;33m[%s WARN]\033[0m %s\n' "$(_digi_ts)" "$*" >&2; }
err()  { printf '\033[1;31m[%s ERR ]\033[0m %s\n' "$(_digi_ts)" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ---- machine config --------------------------------------------------------
# Machine name is resolved by lib/machine-name.sh (NOT `hostname -s`, which
# floats with the network on macOS). Pinned in etc/machine-name by install.sh.
source "${DIGI_LIB_DIR}/machine-name.sh"
DIGI_HOSTNAME="$(digi_machine_name "$DIGI_ETC_DIR")"
DIGI_MACHINE_CONFIG="${DIGI_ETC_DIR}/machines/${DIGI_HOSTNAME}.yaml"

# Read a key from the per-machine yaml. Requires `yq` (installed via Brewfile).
# Usage: capture_root="$(machine_get .paths.capture_root)"
machine_get() {
  local key="$1"
  [[ -f "$DIGI_MACHINE_CONFIG" ]] || die "No machine config at $DIGI_MACHINE_CONFIG (machine name from $(digi_machine_name_source "$DIGI_ETC_DIR")). Run install.sh, or set etc/machine-name to match an existing etc/machines/*.yaml."
  command -v yq >/dev/null 2>&1 || die "yq not installed (brew install yq)"
  yq -r "$key // \"\"" "$DIGI_MACHINE_CONFIG"
}

# ---- misc ------------------------------------------------------------------
require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "Required command not found: $c"
  done
}

confirm() {
  # confirm "Are you sure?" → returns 0 if user types y/Y
  local prompt="${1:-Continue?} [y/N] "
  read -r -p "$prompt" reply
  [[ "$reply" =~ ^[yY]$ ]]
}
