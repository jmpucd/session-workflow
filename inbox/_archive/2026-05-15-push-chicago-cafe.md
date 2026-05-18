# 2026-05-15 — Chicago Cafe (D-822) push

## Task
1. Push `/Volumes/Mini_2/Chicago_Cafe_fix/D-822_Chicago_Cafe_Records`
   → centos:`/digitization/Final_Output_Masters_Backup/Smaller_Requests/D-Collections/`
   over rsync+SSH, excluding mac/Bridge cruft.
2. Then push from centos → ASC server. **TBD** — see questions below.

## Run (in order)

```bash
cd ~/code/digitization-tasks-helper

# 1. Clean stale .md5s + generate a fresh MANIFEST.md5 at the source root.
./inbox/2026-05-15-md5-prep.sh --dry-run     # preview
./inbox/2026-05-15-md5-prep.sh               # real (will prompt before delete)

# 2. Push to centos. MANIFEST.md5 rides along with the data.
./inbox/2026-05-15-push-chicago-cafe.sh --dry-run
./inbox/2026-05-15-push-chicago-cafe.sh

# 3. Verify on centos via md5sum -c MANIFEST.md5.
./inbox/2026-05-15-md5-verify-remote.sh
```

If your centos username isn't `jmpike`, prefix with `REMOTE_USER=youruser ...`.

## Decisions made
- Used the Tailscale IP `100.119.213.45` (works from home).
- Trailing slash on source → contents copied into a freshly-`mkdir -p`'d
  same-named dir on remote; no double-nesting.
- `--no-perms --no-owner --no-group` + explicit `--chmod=...` to avoid the
  macOS<->Linux ownership/perm war.
- Excluded Bridge artifacts: `.BridgeSort`, `.BridgeCache`, `.BridgeCacheT`,
  `Adobe Bridge Cache*`, `*.bc`, `*.bct`. **Sidecar XMP files are kept** —
  they hold real metadata.
- Excluded Capture One `Cache/` + `Proxies/` defensively in case the path
  ever points at a session.

## Questions for the ASC leg
- [ ] ASC server hostname or IP?
- [ ] Destination path on ASC?
- [ ] Auth: SSH key from centos already trusted, or needs setup?
- [ ] Same-rack means there's a local mount path — is it faster to `cp`/local
      rsync via that mount than SSH between the two?
- [ ] Should the ASC push happen automatically after the centos one finishes,
      or stay a manual second step (so you can verify first)?

## Promotion plan
This script + the eventual ASC step should become `digi push <local_path> <remote_alias>`,
with remotes defined in `etc/machines/<host>.yaml` under `remotes:`. The
exclude list moves into `etc/shared/defaults.yaml`. Do this once we've run it
twice and confirmed the shape.
