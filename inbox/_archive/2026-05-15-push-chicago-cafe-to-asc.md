# Push Chicago Cafe → basil (ASC)

Runs on **CentOS** (`100.119.213.45`), not on a Mac. The source is already there
from the Mac→CentOS leg.

## Source / dest
- **Src:** `/digitization/Final_Output_Masters_Backup/Smaller_Requests/D-Collections/D-822_Chicago_Cafe_Records` (on CentOS)
- **Dst:** `basil.lib.ucdavis.edu:/var/digitalcoll/archive/Special_Collections/uploads/D-Collections/D-822_Chicago_Cafe_Records`
- **Auth:** ssh key (`jmpike@basil`)

## Steps to run

1. SSH to CentOS, copy/clone repo there if not present:
   ```
   ssh jmpike@100.119.213.45
   cd ~/digitization-tasks-helper/inbox    # or wherever the repo lives on CentOS
   ```

2. Dry-run first:
   ```
   ./2026-05-15-push-chicago-cafe-to-asc.sh --dry-run
   ```

3. Real run, detached:
   ```
   nohup ./2026-05-15-push-chicago-cafe-to-asc.sh > push-asc.log 2>&1 &
   tail -f push-asc.log
   ```
   Or under screen:
   ```
   screen -S push-asc
   ./2026-05-15-push-chicago-cafe-to-asc.sh
   # Ctrl-A D to detach, screen -r push-asc to come back
   ```

## What it does
1. Tests ssh to basil (batch mode, fails fast on auth issues).
2. Ensures remote dir exists.
3. rsync `-avhP` with the standard exclude list (DS_Store, Bridge cache, etc.).
4. Verifies on basil with `md5sum -c MANIFEST.md5` (uses the manifest generated
   during the md5-prep step on the Mac, which traveled along with the files).

## Failure modes to watch
- **SSH key missing on CentOS for basil** → step 1 fails immediately. Generate
  with `ssh-keygen -t ed25519` on CentOS and add to basil's `authorized_keys`.
- **MANIFEST.md5 missing** → script bails before rsync. Confirms the upstream
  leg actually wrote the manifest at the source root.
- **Verify mismatch** → mismatched files are printed by `md5sum -c`; re-run the
  script (rsync is idempotent) and re-verify.

## Promote to `digi push-to-asc`?
After this runs successfully, promote to `bin/digi-push-to-asc <collection>`
with collection name as an arg. Until then it lives in inbox/.
