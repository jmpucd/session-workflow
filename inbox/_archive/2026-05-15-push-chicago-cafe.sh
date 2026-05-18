#!/usr/bin/env bash
# Push D-822 Chicago Cafe Records → CentOS backup over rsync/SSH.
# Source:  external SSD, working copy on Mac
# Dest:    centos server (Tailscale IP), Smaller_Requests/D-Collections
#
# Usage:
#   ./inbox/2026-05-15-push-chicago-cafe.sh           # real run
#   ./inbox/2026-05-15-push-chicago-cafe.sh --dry-run # show what would copy
#
# Notes for promotion (see NOTES.md): this should become `digi push <path> <remote>`.

set -euo pipefail

SRC="/Volumes/Mini_2/Chicago_Cafe_fix/D-822_Chicago_Cafe_Records"
REMOTE_USER="${REMOTE_USER:-jmpike}"  # override if your centos user differs
REMOTE_HOST="100.119.213.45"
REMOTE_BASE="/digitization/Final_Output_Masters_Backup/Smaller_Requests/D-Collections"

DRY=""
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY="--dry-run"
  echo "[dry-run mode]"
fi

# Sanity checks ----------------------------------------------------------------
if [[ ! -d "$SRC" ]]; then
  echo "ERROR: source not found: $SRC" >&2
  echo "Is the Mini_2 drive mounted?" >&2
  exit 1
fi

# Trailing slash matters: with /, we copy the *contents* into a same-named
# remote dir we create. Without /, rsync would nest one level deeper.
SRC_LEAF="$(basename "$SRC")"
DEST="${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BASE}/${SRC_LEAF}/"

echo "Source:      $SRC"
echo "Destination: $DEST"
echo

# Make sure the parent dir exists on the remote.
echo "[step 1/2] Ensuring remote parent dir exists..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_BASE}/${SRC_LEAF}'"

# Rsync ------------------------------------------------------------------------
# -a   archive (perms, times, recursive, symlinks)
# -h   human-readable sizes
# -v   verbose (one line per file)
# -P   progress + partial (resumable on big files)
# --info=stats2  end-of-run summary
# --no-perms / --no-owner / --no-group: macOS<->linux perm translation is
#   noisy and usually wrong; let the dest filesystem own perms.
# --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r: deterministic perms on the remote.
RSYNC_FLAGS=(-rltvhP --info=stats2 --no-perms --no-owner --no-group
             --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r)

# Exclude patterns (mac/finder junk + Adobe Bridge sort/cache cruft).
# .DS_Store / ._*           AppleDouble + Finder metadata
# .Spotlight-V100/ .Trashes/ .fseventsd/ .TemporaryItems  macOS volume cruft
# .apdisk                   APFS volume marker
# Bridge:
#   .BridgeSort, .BridgeCache, .BridgeCacheT
#   "Adobe Bridge Cache*"   (folder name with space — quoted)
#   *.bc, *.bct             Bridge cache file extensions
# Capture One previews/cache (skip if you happen to point this at a session):
#   Cache/, Proxies/
EXCLUDES=(
  ".DS_Store"
  "._*"
  ".Spotlight-V100"
  ".Trashes"
  ".fseventsd"
  ".TemporaryItems"
  ".apdisk"
  ".BridgeSort"
  ".BridgeCache"
  ".BridgeCacheT"
  "Adobe Bridge Cache*"
  "*.bc"
  "*.bct"
  "Cache"
  "Proxies"
)

EXCLUDE_ARGS=()
for pat in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$pat")
done

echo "[step 2/2] rsync to centos..."
echo
# Note: source path has trailing slash → copy contents into the dest dir
#       we just mkdir'd. This avoids a double-nested D-822/D-822 path.
rsync $DRY "${RSYNC_FLAGS[@]}" "${EXCLUDE_ARGS[@]}" "${SRC}/" "$DEST"

echo
echo "✓ Push complete."
echo
echo "Next: push from centos → ASC server."
echo "      (See NOTES.md — ASC host/path TBD.)"
