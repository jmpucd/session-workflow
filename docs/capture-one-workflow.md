# Capture One session workflow

Short version: **`park`** when you're done capturing, **`checkout`** when
you're ready to edit, **`checkin`** when you're done editing. That's it.

Sessions live on the Synology when nobody's working on them. When you check
one out, it copies down to a fast local drive so Capture One runs at full
speed. When you check it back in, it goes back to the Synology so anyone can
grab it next.

## The three commands

### `digi park` — finished capturing, send it to the queue

Run this on the **capture station** when you're done shooting a session.

```
$ digi park
Pick a session to park:
  1) D-823_Some_Collection   (54 GB, 1,204 files)
> 1
Who are you?
  > sam
Parking D-823_Some_Collection ...
✓ Parked. Session is now in the queue.
```

What happens:

1. The session rsyncs from `~/Pictures/capture_sessions/` to the Synology.
2. The local copy on the capture station is removed.
3. The action is logged.

**If Capture One has the session open, this will refuse.** Close the session
in Capture One first.

### Why `park` might feel fast (background presync)

On the capture station, `digi presync` runs quietly in the background
(every 60 seconds, via launchd — see `etc/launchd/`) the whole time you're
shooting. It copies raw capture files (`.IIQ`/`.CR3`) over to the Synology
as soon as each one has sat still for a minute — long enough to know the
camera's actually done writing it — while leaving the session's database
alone, since that's the one file that's genuinely unsafe to copy while
Capture One still has it open.

That means most of a session's data is usually already on the Synology
*before* you ever run `park`. `park` still does a full sync (so it also
catches whatever wasn't old enough yet, plus the database), but it's often
just picking up the last few files — the slow part happened earlier,
spread out over the whole shoot instead of dumped on you right when you're
trying to hand off.

A session mid-presync (or mid-park) is invisible to everyone else — it
won't show up in `digi queue`/`digi status`, and `digi checkout` refuses
it outright — until the transfer is fully verified. So presync moves data
early, but never makes a session available on its own; only a completed
`park` does that.

### `digi checkout` — pick a session to work on

Run this on whichever Mac you're sitting at (yours, edit-mini-1, edit-mini-2).

```
$ digi checkout
Checkout > D-823_Some_Collection
Who are you?
  > sam
Checking out D-823_Some_Collection ...
✓ Checked out. Local copy: /Volumes/Edit_SSD/capture_sessions/D-823_Some_Collection
```

What happens:

1. The session rsyncs from the Synology to this Mac's working drive.
2. A lock file is written on the Synology saying "Sam on edit-mini-1 has this."
3. The action is logged.

Now open the session in Capture One from the local working drive and work
normally. When two people try to check out the same session, the second one
will see a clear error: "checked out by Sam on edit-mini-1 since 10:30 AM."

### `digi checkin` — done editing, push it back

Run this on the same Mac where you checked it out.

```
$ digi checkin
Checking in: D-823_Some_Collection (only one held by this mac)
What stage of work did you finish?
  1) crop
  2) qa-qc
  3) done
  4) other
> 2
Notes (optional, one line): cropped half the images, ready for QA
Checking in D-823_Some_Collection ...
✓ Checked in. Lock released.
```

What happens:

1. **Close the session in Capture One first.** Checkin will refuse if it's still open.
2. The session rsyncs from your working drive back to the Synology.
3. The lock is released so someone else can check it out next.
4. The stage + notes go into the shared log.

Your local copy is **not** deleted — it sits on your TB SSD as a safety net.
Clean it up manually when you trust the Synology copy.

### `digi complete` — imaging's done, hide it from the queue

Run this on any Mac once a session is genuinely finished (not just checked
in for now) — session must not be checked out.

```
$ digi complete
Mark complete > D-823_Some_Collection
Who are you?
  > sam
Notes (optional, one line): delivered to QA, ready for close-out
✓ Marked complete. D-823_Some_Collection is hidden from 'digi queue' and 'digi checkout'.
```

This is a **label, not an archive** — the session stays exactly where it
is on the Synology and no space is freed. It just stops showing up in
`digi queue` / `digi status` / `digi checkout`'s picker so nobody
accidentally checks out finished work. `digi queue --all` still lists it.

Changed your mind? Run `digi complete <session>` again — it notices the
existing marker and offers to un-mark it.

## The other commands

- **`digi queue`** — what's waiting in the queue + what's checked out
  (`digi queue --all` also shows sessions marked complete)
- **`digi status`** — what's on this Mac + what's elsewhere
- **`digi log -n 20`** — last 20 events (park, checkout, checkin, complete)
- **`digi log --session D-823_Some_Collection`** — history of one session

## Admin

- **`digi force-unlock <session>`** — clear a stale lock (someone crashed,
  forgot to check in, etc.). Requires a written reason; gets logged. Don't use
  this without confirming the actual holder isn't still working.

## Common scenarios

**"I want to check this session out for QA but someone has it for cropping."**

Look at `digi queue` — it tells you who has it. Talk to them. When they're
done, they'll `digi checkin` and the session goes back in the queue.

**"I started editing but I'm going home, want my coworker to finish."**

Two options. Either `digi checkin` it back to the Synology (with notes
explaining where you left off), and your coworker `digi checkout`s in the
morning. Or leave the lock alone; they can use `digi force-unlock` and
checkout — coordinate so they know what they're picking up.

**"I parked something but want to undo it."**

`digi checkout` it again right away. The session comes back to your Mac and
the lock says you have it.

**"The Synology isn't mounted."**

Every command will fail with a clear "Synology not mounted at /Volumes/..."
message. Mount the share (Finder → Go → Connect to Server) and re-run.

**"Capture One won't let me open the session from the local working drive."**

Make sure you're opening it from the path `digi checkout` reported (e.g.
`/Volumes/Edit_SSD/capture_sessions/...`), not from the Synology directly.
The Synology copy is the parked/queued version and should not be opened
directly in Capture One while it's checked out.
