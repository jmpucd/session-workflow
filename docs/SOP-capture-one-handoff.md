# SOP: Capture One Session Handoff

| Field           | Value                                             |
|-----------------|---------------------------------------------------|
| **Owner**       | John Pike, Digitization Services Specialist       |
| **Audience**    | John + student assistants                         |
| **Version**     | 1.0                                               |
| **Effective**   | 2026-05-17                                        |
| **Review**      | Annually, or when the workflow changes            |
| **Tool**        | `digi` (UC Davis Library digitization-tasks-helper) |

---

## 1. Purpose

Establish a single, repeatable procedure for moving a Capture One session
from the capture station to a editing/QA workstation, and back again, so
that:

- A session is always in exactly one place at a time.
- The team knows at a glance where every session is and who has it.
- Two people never edit the same session simultaneously.
- Work is preserved across machines, including color tags, ratings, and
  crops carried in the `.cosessiondb`.

## 2. Scope

Covers all Capture One sessions captured on the Mac Studio (`mac-studio-versa`)
and edited or QA'd on `mac-mini-edit-1`, `mac-mini-edit-2`, or the capture
station itself. Does not cover Special Collections delivery, long-term ASC
archival, or AV digitization — those have separate SOPs.

## 3. Storage model

| Location                                    | Role                       | Who reads/writes |
|---------------------------------------------|----------------------------|------------------|
| Capture station: `~/Pictures/capture_sessions/` | Where fresh captures land | Capture One during capture; `digi park` removes when done |
| Synology: `<share>/capture_sessions/`       | Canonical queue — single source of truth when nobody is editing | `digi park` writes; `digi checkout`/`checkin` read & write |
| Each mini's TB SSD: `/Volumes/<TB-SSD>/capture_sessions/` | Fast local working copy while editing | `digi checkout` writes; `digi checkin` reads |

**A session is in exactly one of three states:**

1. **Capturing** — on the capture station's internal drive only.
2. **Parked** — on the Synology only; no lock file present.
3. **Checked out** — on Synology AND on exactly one mini's TB SSD; lock file
   on the Synology copy names the holder.

## 4. Roles

- **Capture operator** (student or John): captures images on the capture
  station, runs `digi park` when the session is complete.
- **Editor / QA reviewer** (student or John): runs `digi checkout` on
  whichever Mac they're at, edits in Capture One, runs `digi checkin` when
  done.
- **Admin** (John): clears stale locks with `digi force-unlock`, manages
  user list in `etc/shared/users.yaml`.

## 5. Procedure

### 5.1 Park a session (capture complete)

**On the capture station, after capture is finished:**

1. In Capture One, **close the session** (File → Close Session, or quit
   Capture One). If the session is still open, `digi park` will refuse.
2. Open Terminal.
3. Run:
   ```
   digi park
   ```
4. Select the session from the picker.
5. Select your name from the "Who are you?" picker.
6. Wait for rsync to complete. The local copy is removed automatically.
7. Verify with:
   ```
   digi queue
   ```
   The session should appear as **available**.

### 5.2 Check out a session (start editing or QA)

**On the Mac where you'll do the work** (any mini, or the capture station
for occasional QA):

1. Confirm the Synology is mounted (look for `/Volumes/<share>/` in Finder).
2. Open Terminal.
3. Run:
   ```
   digi checkout
   ```
4. Select an available session. (Sessions already checked out are hidden
   from this picker; if you need one of them, talk to the current holder
   first.)
5. Select your name.
6. Wait for rsync to complete. The session is now on this Mac's TB SSD.
7. In Capture One: **File → Open Session…** and navigate to the path the
   tool reported (e.g. `/Volumes/Edit_SSD/capture_sessions/D-823_…`).
   Do **not** open the session directly from the Synology share.

### 5.3 Check in a session (work complete or pausing)

**On the same Mac where you ran `digi checkout`:**

1. In Capture One, **close the session** (File → Close Session, or quit
   Capture One). Checkin will refuse if it's still open.
2. Open Terminal.
3. Run:
   ```
   digi checkin
   ```
4. If you have only one session checked out, it's selected automatically.
   Otherwise, pick from the list.
5. Select the stage you completed:
   - **crop** — finished or progressed on cropping
   - **qa-qc** — finished or progressed on QA/QC
   - **done** — session is complete and ready for delivery
   - **other** — type a description
6. Type a one-line note (optional but encouraged: where you stopped, what
   needs attention next).
7. Wait for rsync to complete. The lock is released; the session is back in
   the queue and available.
8. Verify with `digi queue`. The session is now **available** again.
9. The local copy on the TB SSD is **not** auto-deleted. Once you trust the
   Synology copy (run `digi queue` and confirm it appears available), you
   may manually delete the local copy to reclaim SSD space.

### 5.4 Check status

At any time, on any Mac:

- `digi queue` — full list of parked + checked-out sessions
- `digi status` — what's on this Mac, what's elsewhere, count of available
- `digi log -n 20` — last 20 events (park, checkout, checkin)
- `digi log --session D-823_Some_Collection` — history of one session

## 6. Safety rules (do not skip)

| Rule | Why |
|------|-----|
| Always close the Capture One session before `park` or `checkin`. | A session DB write in progress will be copied in an inconsistent state. The tool refuses if it detects `*.cosessiondb-wal/shm` and a running Capture One process, but don't rely on it. |
| Never open a session directly from the Synology share for editing. | The Synology copy is the canonical queue. Editing it directly bypasses the lock and risks two people editing it at once. Always `checkout` to a local SSD first. |
| Never delete the Synology copy of a session manually. | The Synology copy is the source of truth. If something goes wrong and you need to undo, the admin will recover from there. |
| Never `force-unlock` a session without confirming the listed holder is not actively working. | You can clobber unsaved adjustments. Coordinate first; force-unlock is for genuinely stale locks (crashed machine, vacation, etc.). |

## 7. Errors and what to do

| Message | Cause | Resolution |
|---------|-------|------------|
| `Synology not mounted (or path wrong): /Volumes/<share>/...` | Synology share isn't mounted on this Mac. | Finder → Go → Connect to Server → mount the share. Re-run the command. |
| `Capture One looks like it has '<session>' open. Close the session and try again.` | Session is still open in Capture One. | Close the session in Capture One (or quit it). Re-run the command. |
| `Session is already checked out by <user> on <mac> (since <time>). Use 'digi force-unlock' only if stale.` | Someone else has it. | Talk to that person. If they're done, they should `digi checkin`. Use `force-unlock` only after coordination. |
| `Lock is held by <other-mac>, not this machine. Refusing to check in.` | You're running `checkin` on a Mac that didn't check out this session. | Move to the right Mac. Or, if the right Mac is unavailable, have an admin `force-unlock` and re-checkout. |
| `Nothing is checked out on <hostname>.` | You ran `digi checkin` but this Mac doesn't hold any locks. | Check `digi status` — maybe you're on the wrong Mac, or you checked it in already. |
| `Local copy missing: <path>` | The local working copy was deleted before you ran `checkin`. | The Synology copy is intact. You'll need to re-`checkout` and redo any local-only edits. |

## 8. Escalation

If any of these happen, stop and contact John:

- The Synology share will not mount, or files are missing from a parked session.
- A `digi force-unlock` operation reveals the previous holder didn't actually
  finish their work.
- Capture One reports a corrupt or unreadable `.cosessiondb` after checkout.
- Any rsync error that doesn't resolve on retry.

## 9. Admin procedures

### 9.1 Adding a new student

1. Add their name to `etc/shared/users.yaml` (one line under `users:`).
2. Commit and push the change so all Macs see it on `git pull`.
3. Show them this SOP and walk through one park / checkout / checkin loop on
   a test session.

### 9.2 Clearing a stale lock

1. Run `digi queue` and identify the stuck session.
2. Confirm by chat/in-person that the listed holder is not actively working.
3. Run:
   ```
   digi force-unlock <session-name>
   ```
4. Provide a one-line reason when prompted (e.g., "mac-mini-edit-1 crashed,
   verified with Sam"). This is appended to the shared log with `force-unlock`
   as the action.

### 9.3 Setting up `digi` on a new Mac

1. Clone the repo: `git clone <repo-url> ~/code/digitization-tasks-helper`
2. `cd` in and run `./install.sh`.
3. Edit `etc/machines/<hostname>.yaml`:
   - `role:` set to `capture` or `edit`
   - `paths.capture_root:` — only on the capture station
   - `paths.local_working:` — local working storage (TB SSD path)
   - `sessions.synology_root:` — full path to the Synology session queue
   - `mounts.synology:` — the share mount point (for completeness)
4. Run `digi doctor` to verify all tools and paths are configured.

## 10. Glossary

- **Session** — a Capture One session folder, containing `Captures/`,
  `Output/`, `Selects/`, the `.cosessiondb`, and supporting subfolders.
- **Park** — copy a finished session from the capture station to the
  Synology queue and remove the local copy.
- **Checkout** — copy a queued session from the Synology to a local working
  drive and write a lock so others can't double-grab it.
- **Checkin** — copy local edits back to the Synology and release the lock.
- **Lock file** — `.digi.lock.yaml` inside a session folder on the Synology.
  Presence = checked out; absence = available.
- **TB SSD** — Thunderbolt-attached external SSD used as fast local working
  storage on each mini.

---

*Questions or corrections: John Pike. This SOP is version-controlled in*
*`digitization-tasks-helper/docs/SOP-capture-one-handoff.md`.*
