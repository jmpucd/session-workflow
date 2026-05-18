#!/usr/bin/env bash
# Step 3 (after push): verify checksums on the CentOS side.
# SSHes in, cds to the delivered dir, runs md5sum -c MANIFEST.md5.
# Reports OK / FAILED counts and exits non-zero on any mismatch.

set -euo pipefail

REMOTE_USER="${REMOTE_USER:-jmpike}"
REMOTE_HOST="100.119.213.45"
REMOTE_BASE="/digitization/Final_Output_Masters_Backup/Smaller_Requests/D-Collections"
LEAF="D-822_Chicago_Cafe_Records"

REMOTE_DIR="${REMOTE_BASE}/${LEAF}"

echo "Verifying ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/MANIFEST.md5 ..."
echo

# Run md5sum -c on the remote. --quiet only prints failures, but we still want
# the OK count, so we pipe through awk to count + show failures.
ssh "${REMOTE_USER}@${REMOTE_HOST}" "
  set -e
  cd '${REMOTE_DIR}'
  if [[ ! -f MANIFEST.md5 ]]; then
    echo 'ERROR: MANIFEST.md5 not found on remote' >&2
    exit 2
  fi
  total=\$(wc -l < MANIFEST.md5)
  echo \"Checking \$total files...\"
  # --quiet: suppress 'OK' lines; failures + summary still print.
  if md5sum --quiet -c MANIFEST.md5; then
    echo \"✓ All \$total files verified OK on remote.\"
  else
    echo \"✗ One or more files failed verification (see above).\" >&2
    exit 1
  fi
"
