# Deployment checklist — rolling `digi` out to the Macs

Rolls the Capture One handoff system onto all four machines. Every step is
**idempotent** — safe to re-run, safe if it was already done. Work top to
bottom on each machine. `install.sh` handles Homebrew deps and the symlink;
you only hand-edit the per-machine config.

Assumes: all machines Apple Silicon, repo cloned over HTTPS from
`https://github.com/jmpucd/session-workflow.git`. Reach each box over
Tailscale (SSH or Screen Sharing).

**Roll out in this order:** Versa → mini-1 → mini-2 → MacBook. Do the
one-time Synology step during the Versa pass.

---

## Every machine — the common steps

```bash
# 1. Get the code (clone if new, pull if already there)
mkdir -p ~/code
git clone https://github.com/jmpucd/session-workflow.git ~/code/digitization-tasks-helper 2>/dev/null \
  || (cd ~/code/digitization-tasks-helper && git pull)
cd ~/code/digitization-tasks-helper

# 2. Install deps + create this machine's config + symlink digi
./install.sh

# 3. If install.sh warned that ~/.local/bin isn't on PATH, add it once:
grep -q '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
#    then open a new Terminal tab so `digi` is found.
```

Then edit **this machine's** config — `install.sh` prints the path
(`etc/machines/$(hostname -s).yaml`). Use the matching block below.

Finish every machine with:

```bash
digi doctor      # everything green/normal; no red, no packed .eip
```

---

## Versa (Mac Studio — capture station)

**Config** (`etc/machines/<versa-hostname>.yaml`):

```yaml
role: capture
paths:
  capture_root: ~/Pictures/capture_sessions
  local_working: ~/Pictures/capture_sessions
sessions:
  synology_root: /Volumes/<SYNOLOGY-SHARE>/capture_sessions
```

**One-time, from the Versa (has the Synology mounted):**

```bash
mkdir -p ~/Pictures/capture_sessions
mkdir -p /Volumes/<SYNOLOGY-SHARE>/capture_sessions   # the shared queue
```

**Capture One — set imports UNPACKED (required):**

- Preferences → Image → **uncheck "Pack as EIP."**
- Existing packed sessions must be unpacked before they'll move: `digi doctor`
  lists any session still holding `.eip` files. For each, in Capture One
  select the images → **Image → Unpack** (right-click also has it).

> Swap `<SYNOLOGY-SHARE>` for the real name under `/Volumes/`.

---

## mini-1 and mini-2 (M4 minis — edit / QA)

**Config** (`etc/machines/<mini-hostname>.yaml`):

```yaml
role: edit
paths:
  local_working: /Volumes/<TB-SSD>/capture_sessions
sessions:
  synology_root: /Volumes/<SYNOLOGY-SHARE>/capture_sessions
```

**One-time on each mini** (TB SSD plugged in and mounted):

```bash
mkdir -p /Volumes/<TB-SSD>/capture_sessions
```

> `<TB-SSD>` is the drive's name as it appears under `/Volumes/`. Never run
> two drives with the same name at once — macOS renames the second `Name 1`
> and the path breaks.

---

## MacBook (laptop — admin + occasional review)

**Config** (`etc/machines/<macbook-hostname>.yaml`):

```yaml
role: laptop
paths:
  local_working: ~/Pictures/capture_sessions
sessions:
  synology_root: /Volumes/<SYNOLOGY-SHARE>/capture_sessions
```

```bash
mkdir -p ~/Pictures/capture_sessions
```

> Laptop edits happen over Wi-Fi and are slow — fine for the rare crop or for
> running `digi queue` / `digi log` / `digi force-unlock` as admin.

---

## End-to-end smoke test (once all machines are configured)

On the **Versa**, make a throwaway unpacked session and park it:

```bash
mkdir -p ~/Pictures/capture_sessions/TEST_001/Captures
echo fake > ~/Pictures/capture_sessions/TEST_001/Captures/img.IIQ
touch ~/Pictures/capture_sessions/TEST_001/TEST_001.cosessiondb
digi park            # pick TEST_001, pick your name
```

On a **mini**: `digi checkout` → pick `TEST_001` → confirm it lands on the TB
SSD → `digi checkin` (stage "other", note "test"). Then clean up: delete
`TEST_001` from the Synology and the local copy on the mini.

When that round-trips cleanly on at least one mini, you're live.

---

## Onboarding a student (later, not part of rollout)

1. Add their name under `users:` in `etc/shared/users.yaml`; commit + push;
   `git pull` on each Mac.
2. Walk one park/checkout/checkin loop with them using
   `docs/student-one-page-SOP.md`.
