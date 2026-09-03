#!/usr/bin/env python3
"""Move stray, Capture-One-untracked .eip files out of sessions so they can
be parked, without losing track of them.

Background: unpack_all_sessions.py unpacks everything Capture One's own
document model can see, but some .eip files survive — they're database/
filesystem mismatches Capture One's own UI can't reach either (see the
D-738_040_020 investigation: the file sits on disk, un-trashed per the
session's own SQLite database, but no collection — All Images or Trash —
lists it as a live image). digi park refuses to park a session with ANY
.eip left anywhere in it, so these stragglers block clearing space even
though nothing can actually unpack them in place.

This is a one-time backlog-clearing step, not a permanent workflow: going
forward, captures land as loose IIQ/CR3 from the start (Pack as EIP is
already off on Versa), so this situation shouldn't recur.

What it does:
  0. Refuses to run AT ALL if unpack_all_sessions.py or an unpack_session
     .applescript pass looks active anywhere (pgrep). NOT safe to run
     alongside an in-progress unpack pass — learned this the hard way: the
     per-session "is Capture One using this session right now" check below
     has a real gap (its WAL file can be transiently absent even while
     actively working a session), and by the time that check would catch
     it, files can already be mid-flight in the unpack pass's own AppleScript
     loop. This global check is the actual guard; the per-session one below
     is belt-and-suspenders on top of it, not a substitute for it.
  1. Per session, also skips it if Capture One currently has it open (same
     WAL/SHM + process check digi park/checkin use).
  2. Finds every remaining .eip, plus any file elsewhere in the session
     that shares its base filename (Capture One's Cache/Proxies,
     Cache/Thumbnails, Settings153 sidecars — scattered, not co-located).
  3. Moves all of it into capture_root/_orphaned_eips/<session>/<original
     relative path>/, preserving the path so it's obvious where each came
     from. (The leading underscore keeps this folder invisible to every
     digi command and to this script itself — same convention as the
     existing _migration folder.)
  4. Appends one manifest record per file to
     _orphaned_eips/manifest.jsonl: which session, its original relative
     path, where it landed in quarantine, and the Synology path it would
     have gone to (deterministic — same session name — so this is known
     even before that session's own digi park has run). That's what a
     later "go deal with these" pass needs to reunite each file with its
     session, whether or not park already happened by then.

Usage:
    python3 quarantine_orphan_eips.py --dry-run     # see what would move
    python3 quarantine_orphan_eips.py                # do it
    python3 quarantine_orphan_eips.py --only D-738   # one session
"""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


def capture_one_busy(session_dir: Path) -> bool:
    """Mirrors lib/sessions.sh's capture_one_busy: WAL/SHM sidecars present
    AND Capture One running. Either alone is too noisy on its own."""
    has_wal = any(session_dir.glob("*.cosessiondb-wal")) or any(session_dir.glob("*.cosessiondb-shm"))
    if not has_wal:
        return False
    try:
        result = subprocess.run(["pgrep", "-f", "Capture One"], capture_output=True, timeout=10)
    except subprocess.TimeoutExpired:
        return False
    return result.returncode == 0


def find_stray_eips(session_dir: Path):
    return sorted(session_dir.rglob("*.eip"))


# Real raw image data — NEVER treat one of these as a "sidecar" of
# something else, no matter where it lives or what its filename matches.
RAW_IMAGE_EXTENSIONS = {".iiq", ".cr3", ".eip"}


def find_related_files(session_dir: Path, eip_path: Path):
    """Capture One cache/settings sidecars for this one image — scattered
    across Cache/Proxies, Cache/Thumbnails, Settings153/, not sitting next
    to the .eip itself, but always somewhere under a CaptureOne/ folder.

    Matching is deliberately narrow: same base filename stem AND under a
    CaptureOne/ path AND not itself a raw image extension. A same-stem
    match alone is NOT enough — a session can have a real, already-unpacked
    .iiq sitting in its normal location sharing a stem with an unrelated
    orphaned .eip elsewhere (observed on Beinen_Und_Beinenvolker); matching
    on stem alone would have swept up real image data.
    """
    stem = eip_path.stem  # e.g. "D-738_5_3_0033" from "D-738_5_3_0033.eip"
    related = []
    for p in session_dir.rglob(f"{stem}*"):
        if not p.is_file() or p == eip_path:
            continue
        # Require a real boundary right after the stem (name == stem, or
        # stem followed by "."), not just "starts with" — a short stem
        # could otherwise prefix-match an unrelated longer filename.
        if not (p.name == stem or p.name.startswith(stem + ".")):
            continue
        if "CaptureOne" not in p.relative_to(session_dir).parts:
            continue
        if p.suffix.lower() in RAW_IMAGE_EXTENSIONS:
            continue
        related.append(p)
    return related


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(Path.home() / "Pictures" / "capture_sessions"))
    ap.add_argument("--only", default=None, help="Only process this one session name")
    ap.add_argument("--exclude", action="append", default=[],
                     help="Never touch this session, no matter what the busy-check says — repeatable. "
                          "Use this for anything you know is actively being worked on by a human right "
                          "now; don't rely on the busy-check alone for that.")
    ap.add_argument("--dry-run", action="store_true", help="List what would move, change nothing")
    ap.add_argument("--synology-root", default="/Volumes/Digitization_Files/capture_sessions",
                     help="Used only to record the eventual destination path in the manifest — nothing is written there")
    args = ap.parse_args()

    # Global guard, not just the per-session busy check below: tonight's
    # real run hit this — unpack_all_sessions.py builds its list of images
    # to unpack once, then works through it in one long AppleScript call
    # per session. The per-session "does this session look busy right now"
    # check has a real gap (Capture One's WAL file can be transiently
    # absent even while it's actively working a session), and by the time
    # it fires, the unpack pass may already have files mid-flight that
    # this script would then yank out from under it. Simplest reliable
    # fix: don't run AT ALL while an unpack pass might be active, anywhere.
    for pattern in ("unpack_all_sessions.py", "unpack_session.applescript"):
        try:
            result = subprocess.run(["pgrep", "-f", pattern], capture_output=True, timeout=10)
        except subprocess.TimeoutExpired:
            continue
        if result.returncode == 0:
            print(f"Refusing to run: '{pattern}' is currently active — an unpack pass may be")
            print("mid-flight. Wait for it to finish (check with 'screen -r' or 'ps aux | grep")
            print("unpack'), then re-run this.")
            sys.exit(1)

    root = Path(args.root)
    if not root.is_dir():
        print(f"No such directory: {root}", file=sys.stderr)
        sys.exit(1)

    quarantine_root = root / "_orphaned_eips"
    manifest_path = quarantine_root / "manifest.jsonl"

    sessions = []
    for d in sorted(root.iterdir()):
        if not d.is_dir() or d.name.startswith((".", "_")):
            continue
        if d.name in args.exclude:
            print(f"--- {d.name}: excluded, skipping ---")
            continue
        if args.only and d.name != args.only:
            continue
        sessions.append(d)

    total_moved = 0
    for session_dir in sessions:
        name = session_dir.name

        strays = find_stray_eips(session_dir)
        if not strays:
            continue

        if capture_one_busy(session_dir):
            print(f"--- {name}: SKIPPED (Capture One has it open right now) ---")
            continue

        print(f"--- {name}: {len(strays)} stray .eip file(s) ---")
        for eip_path in strays:
            rel = eip_path.relative_to(session_dir)
            related = find_related_files(session_dir, eip_path)
            all_files = [eip_path] + related

            for f in all_files:
                f_rel = f.relative_to(session_dir)
                dest = quarantine_root / name / f_rel
                print(f"  {'[dry-run] would move' if args.dry_run else 'moving'}: {f_rel} -> {dest.relative_to(root)}")
                if not args.dry_run:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(f), str(dest))

            if not args.dry_run:
                manifest_path.parent.mkdir(parents=True, exist_ok=True)
                with manifest_path.open("a") as mf:
                    mf.write(json.dumps({
                        "session": name,
                        "relative_path": str(rel),
                        "quarantined_path": str(quarantine_root / name / rel),
                        "synology_dest_path": str(Path(args.synology_root) / name / rel),
                        "related_files_moved": [str(f.relative_to(session_dir)) for f in related],
                        "quarantined_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    }) + "\n")
            total_moved += 1

    if args.dry_run:
        print(f"\n(dry run — {total_moved} file(s) would be quarantined, nothing changed)")
    else:
        print(f"\nDone. {total_moved} orphan .eip file(s) quarantined to {quarantine_root}")
        print(f"Manifest: {manifest_path}")
        print("Affected sessions should now show 0 .eip via 'digi doctor' and are safe to 'digi park'.")


if __name__ == "__main__":
    main()
