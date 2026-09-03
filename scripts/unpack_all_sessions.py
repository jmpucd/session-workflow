#!/usr/bin/env python3
"""One-off maintenance script: bulk-unpack packed (.eip) Capture One sessions.

Drives Capture One's real AppleScript `unpack` command (see
unpack_session.applescript) across every packed session under a capture
root, so you don't have to open each one, select All Images, run Unpack,
then go clean up the Trash collection, by hand, 46 times.

Run this ON the capture station (Versa) — it needs Capture One installed
and macOS's Automation permission already granted for this terminal/SSH
session to control "Capture One 23" (macOS will prompt for this on first
use; someone has to be at the physical console or a screen-share to
approve it).

Usage:
    python3 unpack_all_sessions.py --dry-run              # see what would run
    python3 unpack_all_sessions.py --limit 2               # just the 2 smallest
    python3 unpack_all_sessions.py --only "D-738_040_020"  # one named session
    python3 unpack_all_sessions.py                         # everything, smallest first

Re-run `digi doctor` afterward to confirm the .eip counts dropped, then
`digi park` each session that's now clean.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
APPLESCRIPT = SCRIPT_DIR / "unpack_session.applescript"


def find_packed_sessions(root: Path):
    sessions = []
    for d in sorted(root.iterdir()):
        if not d.is_dir() or d.name.startswith((".", "_")):
            continue
        cosessiondb = d / f"{d.name}.cosessiondb"
        if not cosessiondb.exists():
            continue
        eip_count = sum(1 for _ in d.rglob("*.eip"))
        if eip_count > 0:
            sessions.append((d.name, cosessiondb, eip_count))
    return sessions


def count_eip(session_dir: Path) -> int:
    return sum(1 for _ in session_dir.rglob("*.eip"))


def unpack_one(cosessiondb: Path, trash_policy: str, timeout_s: int):
    cmd = ["osascript", str(APPLESCRIPT), str(cosessiondb), trash_policy]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
    except subprocess.TimeoutExpired:
        return False, f"TIMEOUT after {timeout_s}s (session may be stuck on a dialog — check the screen)"
    if result.returncode != 0:
        return False, (result.stderr or result.stdout).strip()
    return True, result.stdout.strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(Path.home() / "Pictures" / "capture_sessions"))
    ap.add_argument("--trash-policy", choices=["unpack-trash", "delete-trash"], default="unpack-trash",
                     help="What to do with images that land in the session's Trash during unpack (default: unpack them too, nothing deleted)")
    ap.add_argument("--limit", type=int, default=None, help="Only process the first N sessions (smallest .eip count first)")
    ap.add_argument("--only", default=None, help="Only process this one session name")
    ap.add_argument("--dry-run", action="store_true", help="List what would be processed, change nothing")
    ap.add_argument("--timeout", type=int, default=1800, help="Per-session AppleScript timeout in seconds (default 1800 = 30min)")
    args = ap.parse_args()

    root = Path(args.root)
    if not root.is_dir():
        print(f"No such directory: {root}", file=sys.stderr)
        sys.exit(1)

    sessions = find_packed_sessions(root)
    sessions.sort(key=lambda s: s[2])  # smallest first

    if args.only:
        sessions = [s for s in sessions if s[0] == args.only]
        if not sessions:
            print(f"No packed session named {args.only!r} found under {root}")
            sys.exit(1)
    elif args.limit:
        sessions = sessions[: args.limit]

    if not sessions:
        print(f"No packed (.eip) sessions found under {root}. Nothing to do.")
        return

    print(f"{len(sessions)} packed session(s) to process (trash policy: {args.trash_policy}):")
    for name, _, n in sessions:
        print(f"  {n:6d}  {name}")

    if args.dry_run:
        print("\n(dry run — nothing changed)")
        return

    log_path = SCRIPT_DIR / f"unpack-log-{time.strftime('%Y%m%d-%H%M%S')}.jsonl"
    print(f"\nLogging to {log_path}\n")

    failures = []
    leftovers = []
    for name, cosessiondb, eip_before in sessions:
        session_dir = cosessiondb.parent
        print(f"--- {name} ({eip_before} .eip) ---", flush=True)
        t0 = time.time()
        ok, message = unpack_one(cosessiondb, args.trash_policy, args.timeout)
        elapsed = time.time() - t0
        status = "OK" if ok else "FAIL"
        print(f"{status} ({elapsed:.0f}s): {message}")
        if not ok:
            failures.append(name)

        # Capture One's own "Trash" collection only reflects images the open
        # document currently tracks — a stray .eip already sitting loose in
        # the session's physical Trash/ folder (e.g. from an earlier partial
        # manual unpack) won't show up there and won't get touched by the
        # AppleScript step above. Recheck the filesystem directly so nothing
        # gets silently missed.
        eip_after = count_eip(session_dir)
        if eip_after > 0:
            stray = sorted(str(p) for p in session_dir.rglob("*.eip"))
            leftovers.append((name, eip_after, stray))
            print(f"  WARNING: {eip_after} .eip file(s) still on disk (likely untracked, e.g. in Trash/) — needs a manual look:")
            for p in stray:
                print(f"    {p}")

        with log_path.open("a") as f:
            f.write(json.dumps({
                "session": name,
                "eip_before": eip_before,
                "eip_after": eip_after,
                "ok": ok,
                "message": message,
                "elapsed_s": round(elapsed, 1),
                "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }) + "\n")

    print(f"\nDone. {len(sessions) - len(failures)}/{len(sessions)} succeeded via AppleScript.")
    if failures:
        print("AppleScript-level failures (check the log, may need a manual pass in Capture One):")
        for name in failures:
            print(f"  {name}")
    if leftovers:
        print(f"\n{len(leftovers)} session(s) still have .eip files on disk after unpacking everything Capture One tracked:")
        for name, n, _ in leftovers:
            print(f"  {n:4d}  {name}")
        print("These are likely untracked stragglers in Trash/ — open the session in Capture One,")
        print("check the Trash, and either drag them back in to unpack or delete them by hand.")
    print("\nRun 'digi doctor' to confirm the .eip counts dropped.")


if __name__ == "__main__":
    main()
