#!/usr/bin/env bash
# Step 1: prep checksums on the source side.
#   - Find & delete stale *.md5 files (they're wrong after reorg)
#   - Generate one MANIFEST.md5 at the top of the source tree
#
# The manifest uses GNU md5sum format (hash  relative/path), so it can be
# verified on the CentOS side with:  md5sum -c MANIFEST.md5
#
# Requires gmd5sum (from coreutils). Install: brew install coreutils

set -euo pipefail

SRC="/Volumes/Mini_2/Chicago_Cafe_fix/D-822_Chicago_Cafe_Records"
MANIFEST_NAME="MANIFEST.md5"

DRY=""
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY=1
  echo "[dry-run mode]"
fi

[[ -d "$SRC" ]] || { echo "ERROR: source not found: $SRC" >&2; exit 1; }
command -v gmd5sum >/dev/null 2>&1 || {
  echo "ERROR: gmd5sum missing. Run: brew install coreutils" >&2; exit 1; }

cd "$SRC"

# ---- 1. Find & remove stale .md5 files ---------------------------------------
echo "[1/2] Scanning for stale *.md5 files in $SRC ..."
mapfile -t STALE < <(find . -type f \( -name "*.md5" -o -name "*.MD5" \) -print)

if (( ${#STALE[@]} == 0 )); then
  echo "      none found."
else
  echo "      found ${#STALE[@]}:"
  printf '        %s\n' "${STALE[@]}"
  if [[ -n "$DRY" ]]; then
    echo "      (dry-run: would delete)"
  else
    read -r -p "      Delete these ${#STALE[@]} files? [y/N] " reply
    if [[ "$reply" =~ ^[yY]$ ]]; then
      printf '%s\0' "${STALE[@]}" | xargs -0 rm -v
    else
      echo "      Skipped delete. Aborting before manifest." >&2
      exit 1
    fi
  fi
fi

# ---- 2. Generate fresh MANIFEST.md5 -----------------------------------------
echo
echo "[2/2] Generating $MANIFEST_NAME ..."

# We hash every regular file EXCEPT:
#   - the manifest itself (would be self-referential)
#   - macOS metadata cruft (.DS_Store, ._*, .Spotlight-V100, .fseventsd, ...)
#   - Bridge cache files (.BridgeSort, *.bc, *.bct, "Adobe Bridge Cache*")
# Same exclusions as the rsync step, so the file set matches exactly.

if [[ -n "$DRY" ]]; then
  echo "      (dry-run: would hash these files)"
  find . -type f \
    ! -name "$MANIFEST_NAME" \
    ! -name ".DS_Store" ! -name "._*" ! -name "*.bc" ! -name "*.bct" \
    ! -name ".BridgeSort" ! -name ".BridgeCache" ! -name ".BridgeCacheT" \
    ! -path "*/.Spotlight-V100/*" ! -path "*/.Trashes/*" \
    ! -path "*/.fseventsd/*" ! -path "*/.TemporaryItems/*" \
    ! -path "*/Adobe Bridge Cache*/*" \
    ! -path "*/Cache/*" ! -path "*/Proxies/*" \
    | sort | head -20
  echo "      ... (showing first 20)"
  exit 0
fi

# Hash in parallel (xargs -P) for speed on big trees. Sort first so manifest
# is deterministic / diff-friendly.
TMP_MANIFEST="$(mktemp)"
trap 'rm -f "$TMP_MANIFEST"' EXIT

find . -type f \
  ! -name "$MANIFEST_NAME" \
  ! -name ".DS_Store" ! -name "._*" ! -name "*.bc" ! -name "*.bct" \
  ! -name ".BridgeSort" ! -name ".BridgeCache" ! -name ".BridgeCacheT" \
  ! -path "*/.Spotlight-V100/*" ! -path "*/.Trashes/*" \
  ! -path "*/.fseventsd/*" ! -path "*/.TemporaryItems/*" \
  ! -path "*/Adobe Bridge Cache*/*" \
  ! -path "*/Cache/*" ! -path "*/Proxies/*" \
  -print0 \
  | sort -z \
  | xargs -0 -n 32 -P 4 gmd5sum > "$TMP_MANIFEST"

# Strip the leading "./" from paths so they verify cleanly anywhere.
sed -E 's| \./| |' "$TMP_MANIFEST" > "$MANIFEST_NAME"

COUNT="$(wc -l < "$MANIFEST_NAME" | tr -d ' ')"
SIZE="$(du -h "$MANIFEST_NAME" | awk '{print $1}')"
echo "      ✓ Wrote $MANIFEST_NAME ($COUNT files, $SIZE)"
echo
echo "Next: run ./inbox/2026-05-15-push-chicago-cafe.sh"
echo "      then ./inbox/2026-05-15-md5-verify-remote.sh"
