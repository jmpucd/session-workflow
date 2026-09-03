#!/usr/bin/env python3
"""Directly unpack .eip files Capture One's own Import won't recognize, by
extracting the ZIP-format .eip container ourselves.

Background (2026-09-03): a batch of 285 .eip files (D-758 sampler, dated
Sept 2024, originally owned by a different machine's account/lab) turned
out to be completely valid — correct ZIP structure, correct Phase One
packaged-image content type, readable, no quarantine flag, same camera
serial as files that work fine — but Capture One's own Import dialog
reported "No unique images in folder" for them regardless. Root cause
undetermined after ruling out corruption, permissions, quarantine,
Spotlight indexing, and camera/license mismatch.

Rather than keep chasing that mystery, this bypasses Capture One's
recognition step entirely: .eip is just a zip container around a plain
.iiq (Capture One's own raw format), its .cos adjustment sidecar, and a
.lcc lens-correction profile. Extracting and renaming those directly
produces exactly the same on-disk layout Capture One's own "Unpack"
command would have produced — verified against a real already-unpacked
session's structure before writing this.

Safety: refuses to overwrite an existing same-named .iiq; verifies the
extracted file's size against the zip's own recorded size before ever
deleting the source .eip.

Usage:
    python3 unpack_eip_directly.py --dry-run <folder>
    python3 unpack_eip_directly.py <folder>
"""
import argparse
import shutil
import sys
import zipfile
from pathlib import Path


def unpack_one(eip_path: Path, dry_run: bool):
    base = eip_path.stem  # e.g. "D-758_5_16-1_02" from "D-758_5_16-1_02.eip"
    dest_dir = eip_path.parent

    try:
        with zipfile.ZipFile(eip_path) as zf:
            names = zf.namelist()
            iiq_name = next(
                (n for n in names if "/" not in n and n.lower().endswith(".iiq")),
                None,
            )
            if not iiq_name:
                return False, f"no top-level .iiq found inside zip (contents: {names[:5]})"

            sidecar_names = [
                n for n in names
                if n.lower().startswith("captureone/settings") and (n.lower().endswith(".cos") or n.lower().endswith(".lcc"))
            ]

            dest_iiq = dest_dir / f"{base}.iiq"
            if dest_iiq.exists():
                return False, f"{dest_iiq.name} already exists, refusing to overwrite"

            if dry_run:
                extras = [f"{base}.iiq" + n.split(".iiq", 1)[1] for n in sidecar_names]
                return True, f"[dry-run] would extract {iiq_name} -> {dest_iiq.name}, plus {extras}"

            expected_size = zf.getinfo(iiq_name).file_size

            with zf.open(iiq_name) as src, open(dest_iiq, "wb") as dst:
                shutil.copyfileobj(src, dst)

            settings_dir = dest_dir / "CaptureOne" / "Settings153"
            for n in sidecar_names:
                # n looks like "CaptureOne/Settings153/0.iiq.cos" or
                # ".../0.iiq.LCC_600ppi_9_10.lcc" — keep everything after
                # ".iiq" so the real basename replaces the generic "0".
                suffix = n.rsplit("/", 1)[-1].split(".iiq", 1)[1]
                dest_sidecar = settings_dir / f"{base}.iiq{suffix}"
                settings_dir.mkdir(parents=True, exist_ok=True)
                with zf.open(n) as src, open(dest_sidecar, "wb") as dst:
                    shutil.copyfileobj(src, dst)

        actual_size = dest_iiq.stat().st_size
        if actual_size != expected_size:
            return False, f"size mismatch after extraction: expected {expected_size}, got {actual_size} — not deleting source"

        eip_path.unlink()
        return True, f"OK: {base}.iiq ({actual_size} bytes) + {len(sidecar_names)} sidecar(s)"

    except zipfile.BadZipFile:
        return False, "not a valid zip/eip file"
    except Exception as e:
        return False, f"error: {e}"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    root = Path(args.folder)
    if not root.is_dir():
        print(f"No such directory: {root}", file=sys.stderr)
        sys.exit(1)

    eips = sorted(root.rglob("*.eip"))
    print(f"{len(eips)} .eip file(s) found under {root}")

    ok_count = 0
    fail = []
    for eip in eips:
        ok, msg = unpack_one(eip, args.dry_run)
        status = "OK" if ok else "FAIL"
        print(f"{status}  {eip.relative_to(root)}  ->  {msg}")
        if ok:
            ok_count += 1
        else:
            fail.append(str(eip.relative_to(root)))

    print(f"\n{ok_count}/{len(eips)} succeeded.")
    if fail:
        print("Failed (left as .eip, needs a manual look):")
        for f in fail:
            print(f"  {f}")


if __name__ == "__main__":
    main()
