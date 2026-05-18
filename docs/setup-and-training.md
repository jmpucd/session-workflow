# Setup & student training

Two short guides in one doc:

1. **Setting up `digi` on a Mac** — do this once per Mac, when you first
   bring it onto the workflow.
2. **Teaching a new student** — about 10 minutes, the first time they sit
   down to do real work.

---

## Part 1: Setting up `digi` on a Mac

You'll do this three times total — once on the Versa Mac Studio, once on
each of the two mac minis. After that you basically never touch it again
unless something breaks.

### What you need before you start

- Homebrew installed. If `brew --version` works in Terminal, you're good.
  If not, install it from https://brew.sh first.
- The Synology share mounted in Finder (Go → Connect to Server → put in
  the share address). Note the path it appears at under `/Volumes/…`.
- (For the two minis only) The Thunderbolt SSD plugged in and mounted.
  Note its path under `/Volumes/…`.

### Steps

1. **Open Terminal** and grab the repo:

   ```
   git clone https://github.com/jmpucd/session-workflow.git ~/code/digitization-tasks-helper
   cd ~/code/digitization-tasks-helper
   ```

2. **Run the installer** — it sets up Homebrew packages and creates the
   per-Mac config file:

   ```
   ./install.sh
   ```

   If it tells you `~/.local/bin` isn't on your PATH, add this line to
   your `~/.zshrc` and reopen Terminal:

   ```
   export PATH="$HOME/.local/bin:$PATH"
   ```

3. **Edit this Mac's config file.** The installer printed its path, but
   you can also find it at:

   ```
   etc/machines/<this-mac's-short-hostname>.yaml
   ```

   Open it in your editor and fill in:

   **On the Versa Mac Studio:**

   ```yaml
   role: capture
   paths:
     capture_root: ~/Pictures/capture_sessions
     local_working: ~/Pictures/capture_sessions
   sessions:
     synology_root: /Volumes/<your-synology-share>/capture_sessions
   ```

   **On each mac mini:**

   ```yaml
   role: edit
   paths:
     local_working: /Volumes/<TB-SSD-volume-name>/capture_sessions
   sessions:
     synology_root: /Volumes/<your-synology-share>/capture_sessions
   ```

   Swap in the real volume names you noted before starting. The TB SSD
   path is whatever shows up under `/Volumes/` when the drive is plugged
   in — usually whatever you named the disk in Disk Utility.

4. **Create the working folders if they don't exist:**

   On the Versa: `mkdir -p ~/Pictures/capture_sessions`
   On each mini: `mkdir -p /Volumes/<TB-SSD>/capture_sessions`

5. **On the Synology**, create the queue folder once (from any Mac that
   has the share mounted):

   ```
   mkdir -p /Volumes/<your-synology-share>/capture_sessions
   ```

6. **Verify everything is wired up:**

   ```
   digi doctor
   ```

   This prints which tools are installed and confirms the paths exist.
   Anything red is a problem — fix it before going further. Anything
   yellow `(unset)` is fine if it's a key that doesn't apply to this
   Mac (e.g. `capture_root` on a mini).

7. **Smoke test.** From the Versa, make a tiny fake session and try
   parking it:

   ```
   mkdir -p ~/Pictures/capture_sessions/TEST_001/Captures
   echo "fake" > ~/Pictures/capture_sessions/TEST_001/Captures/fake.txt
   touch ~/Pictures/capture_sessions/TEST_001/TEST_001.cosessiondb
   digi park
   ```

   Pick `TEST_001`, pick your name. It should show up on the Synology.

   Then on one mini: `digi checkout`, pick `TEST_001`, confirm it lands
   on the TB SSD. Then `digi checkin`, pick stage "other" and type "test".

   When that round-trips cleanly, delete the test session from the
   Synology and the local copy on the mini.

### Common setup hiccups

- **"yq: command not found"** or similar. Run `./install.sh` again — it
  installs the required Homebrew packages. If still broken,
  `brew install yq jq fzf` directly.
- **"Synology not mounted"** errors. Reconnect to the share in Finder.
  macOS occasionally drops these on sleep; the long-term fix is to add
  the share to your Login Items so it remounts at boot.
- **TB SSD path keeps changing.** macOS appends numbers when the same
  volume name mounts twice (`Edit_SSD 1`, `Edit_SSD 2`). Make sure you
  never have two drives with the same name plugged in, and that you
  eject cleanly before unplugging.

---

## Part 2: Teaching a new student

Plan for 10–15 minutes the first time. After this they should be able
to do park/checkout/checkin on their own with the printed SOP as a
reference.

### Before the student arrives

1. Open `etc/shared/users.yaml` and uncomment (or add) their name. Commit
   and push the change. On other Macs run `git pull` so the change is
   visible everywhere:

   ```yaml
   users:
     - john
     - sam        # new student
   ```

2. Make a small test session you can throw away after the lesson —
   capture maybe 5 images, or copy an existing session and rename it
   `TEST_<student-name>`.

3. Have these open or printed:
   - `docs/SOP-capture-one-handoff.md` (the formal procedure)
   - `docs/capture-one-workflow.md` (the casual cheat sheet)

### The 10-minute walkthrough

Tell the student something like this — adjust to your voice:

> "We have three Macs that touch every session. The big Mac Studio over
> there is where we capture. These two minis are where you'll do
> cropping and QA. The Synology in the rack is where sessions live when
> nobody's working on them.
>
> The rule is: only one person works on a session at a time. To make
> that easy, we have three commands — `digi park`, `digi checkout`,
> `digi checkin`. That's basically it.
>
> Here, let me show you on this test session…"

Then walk through, **at the keyboard, with them watching:**

1. **`digi park`** on the Versa.
   - "I just finished capturing this. Watch — `digi park`."
   - Pick the test session. Pick your own name.
   - "See, it copies to the Synology and removes the local one. Now
     it's waiting in the queue."

2. **`digi queue`** on the same Mac.
   - "Anyone, on any Mac, can see what's waiting like this."

3. **Walk to a mini.** Sit the student in front of it.
   - "Now you're going to grab it for cropping. Run `digi checkout`."
   - Have them run it. Pick the test session. Pick their name from the
     list.
   - "See the lock icon? Now nobody else can grab this session — it's
     yours until you check it in."

4. **`digi status`.**
   - "If you ever forget what you have or where it is — `digi status`."

5. **Open the session in Capture One.**
   - "Open it from the path it showed you — that's on the TB SSD, fast.
     Never open it from the Synology directly. We don't want students
     editing across the network share."

6. **Quick mock edit.** Make any trivial change. Then **close the
   session in Capture One** (very important to call this out).

7. **`digi checkin`.**
   - "When you're done — or even when you're stopping for the day —
     `digi checkin`."
   - Have them run it. Pick stage `qa-qc` (or whatever fits). Type a
     note like "test run, half cropped."
   - "Now it's back on the Synology and someone else can grab it."

8. **`digi log -n 5`.**
   - "If you ever want to see what's happened lately — `digi log`."

### Things to drill in explicitly

These are the four mistakes new students make. Say them out loud.

1. **Always close the session in Capture One before park or checkin.**
   If you don't, `digi` will refuse — but don't make it work harder
   than it has to.
2. **Never open a session directly from the Synology share.** Always
   `checkout` first, then open from the local SSD.
3. **Never delete the Synology copy of a session manually.** It's the
   master. Local copies on the TB SSD are fair game once you've
   confirmed checkin worked.
4. **If something looks wrong, stop and ask John.** A 5-minute "is this
   normal?" conversation prevents 5 hours of recovery.

### After the lesson

- Clean up the test session: `digi force-unlock TEST_<student-name>`
  (if it's still locked), then delete from the Synology.
- Show them where the printed SOP is pinned.
- Tell them where to find John if something breaks.

### When they're on their own

Their three-command universe:

```
digi park       (only on the capture station, after capture)
digi checkout   (on whichever Mac they're at, before editing)
digi checkin    (same Mac as checkout, when they're done)
```

And the read-only ones for when they're confused:

```
digi queue
digi status
digi log -n 20
```

That's the whole job.
