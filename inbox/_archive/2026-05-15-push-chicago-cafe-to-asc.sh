#!/usr/bin/env bash
# Push Chicago Cafe (already on CentOS backup) → basil ASC server, then verify.
#
# Run ON CentOS:
#   nohup ./2026-05-15-push-chicago-cafe-to-asc.sh > push-asc.log 2>&1 &
#   tail -f push-asc.log
#
# Or under screen:
#   screen -S push-asc
#   ./2026-05-15-push-chicago-cafe-to-asc.sh
#   (Ctrl-A D to detach)
#
# Dry-run first:
#   ./2026-05-15-push-chicago-cafe-to-asc.sh --dry-run

set -uo pipefail

# ----- config ---------------------------------------------------------------
COLLECTION="D-822_Chicago_Cafe_Records"
SRC_BASE="/digitization/Final_Output_Masters_Backup/Smaller_Requests/D-Collections"
DEST_USER="${DEST_USER:-jmpike}"
DEST_HOST="basil.lib.ucdavis.edu"
DEST_BASE="/var/digitalcoll/archive/Special_Collections/uploads/D-Collections"
# ---------------------------------------------------------------------------

SRC="${SRC_BASE}/${COLLECTION}"
DEST="${DEST_USER}@${DEST_HOST}:${DEST_BASE}/${COLLECTION}"

DRY=""
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY="--dry-run"
  echo "[dry-run]"
fi

[[ -d "$SRC" ]] || { echo "ERROR: source not found: $SRC" >&2; exit 1; }
[[ -f "$SRC/MANIFEST.md5" ]] || { echo "ERROR: no MANIFEST.md5 at $SRC — run md5-prep first" >&2; exit 1; }

echo "Source:      $SRC"
echo "Destination: $DEST"
echo "Started:     $(date)"
echo

echo "[1/4] Test SSH to basil"
ssh -o BatchMode=yes -o ConnectTimeout=10 "${DEST_USER}@${DEST_HOST}" "echo ok" \
  || { echo "ERROR: ssh to basil failed (key auth)" >&2; exit 1; }

echo "[2/4] Ensure remote dir exists"
ssh "${DEST_USER}@${DEST_HOST}" "mkdir -p '${DEST_BASE}/${COLLECTION}'"

echo "[3/4] rsync"
# Same exclude pattern as Mac→CentOS leg. -a is fine here (both Linux).
RSYNC_FLAGS=(-avhP --info=stats2 --no-owner --no-group)
EXCLUDES=(
  ".DS_Store" "._*" ".Spotlight-V100" ".Trashes" ".fseventsd" ".TemporaryItems" ".apdisk"
  ".BridgeSort" ".BridgeCache" ".BridgeCacheT" "Adobe Bridge Cache*" "*.bc" "*.bct"
  "Cache" "Proxies"
)
EXCLUDE_ARGS=()
for pat in "${EXCLUDES[@]}"; do EXCLUDE_ARGS+=(--exclude="$pat"); done

rsync $DRY "${RSYNC_FLAGS[@]}" "${EXCLUDE_ARGS[@]}" "${SRC}/" "$DEST/"
RSYNC_RC=$?
if [[ $RSYNC_RC -ne 0 ]]; then
  echo "ERROR: rsync exited $RSYNC_RC" >&2
  exit $RSYNC_RC
fi

if [[ -n "$DRY" ]]; then
  echo
  echo "[dry-run complete — skipping verify]"
  exit 0
fi

echo "[4/4] Remote verify (md5sum -c MANIFEST.md5 on basil)"
ssh "${DEST_USER}@${DEST_HOST}" "cd '${DEST_BASE}/${COLLECTION}' && md5sum --quiet -c MANIFEST.md5"
VERIFY_RC=$?

echo
echo "Finished: $(date)"
if [[ $VERIFY_RC -eq 0 ]]; then
  echo "✓ All files verified on basil."
else
  echo "✗ Verification FAILED (rc=$VERIFY_RC) — investigate mismatches above." >&2
  exit $VERIFY_RC
fi
