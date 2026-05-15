# digitization-tasks-helper

UC Davis Library — Digitization Services toolkit.

A single repo of small, composable scripts for the digitization workflow:
capture hand-off, backup, AV digitization, course-video compression, and
delivery to Special Collections.

Owned by the Digitization Services Specialist (John Pike).
Used by John + 5 student assistants across the Mac Studio capture station,
two M4 Mac minis, and laptops.

## Install on a new machine

```bash
git clone <repo-url> ~/code/digitization-tasks-helper
cd ~/code/digitization-tasks-helper
./install.sh
```

`install.sh` is idempotent — re-run after every `git pull`.

It will:

1. Install Homebrew dependencies from `Brewfile` (rsync, ffmpeg, exiftool, etc.).
2. Symlink `bin/digi` into `/usr/local/bin` (or `~/.local/bin` on Apple Silicon).
3. Create a per-machine config at `etc/machines/$(hostname -s).yaml` if missing,
   prompting for which role this machine plays (capture / edit / laptop / server).

## Usage

Everything is dispatched through a single `digi` command:

```bash
digi help                    # list available subcommands
digi backup <session>        # back a Capture One session up to NAS + campus
digi sync-session <session>  # hand a Capture One session off to another Mac
digi rip-dvd /dev/disk4      # rip a DVD to ISO + MP4 for instructor use
digi compress-course <file>  # H.264 compress for course delivery
digi deliver <session>       # push finished session to Special Collections drop
```

Each subcommand lives in `bin/digi-<name>` and can also be invoked directly.

## Repo layout

```
bin/         Subcommand executables (digi-backup, digi-rip-dvd, ...)
lib/         Shared shell + Python helpers (logging, config, rsync wrappers)
etc/         Configuration
  machines/  Per-host config (paths, role, mount points)
  shared/    Settings that apply to every machine
inbox/       Scratch space for unstyled scripts John dumps mid-workflow.
             Curated into bin/ + lib/ later.
scripts/     Examples, one-shot maintenance scripts, references
docs/        Runbooks, troubleshooting notes
```

## Working in the inbox

When you find yourself running an ad-hoc command repeatedly, drop it into
`inbox/` with a short note at the top. Don't worry about polish — the goal is
to capture it before it's forgotten. We promote inbox scripts into proper
`bin/digi-*` commands during cleanup passes.

```
inbox/
  2026-05-15-resize-tiff-batch.sh
  2026-05-15-NOTES.md          # what was I doing, what worked, what didn't
```

## Machine roles

| Role     | Hostname (example) | What it does                                    |
|----------|--------------------|-------------------------------------------------|
| capture  | mac-studio-versa   | Phase One iXG + Capture One, primary ingest     |
| edit     | mac-mini-edit-1    | post-processing, batch derivatives              |
| edit     | mac-mini-edit-2    | post-processing, AV digitization                |
| laptop   | jmpike-mbp         | admin, scripting, light review                  |
| nas      | synology           | working storage, transfer hub                   |
| server   | campus-centos      | long-term backup, ffmpeg jobs, SC delivery hub  |

See `etc/machines/README.md` for adding a new machine.
