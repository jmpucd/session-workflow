# Capture One sessions — the only page you need

**You only ever use three commands: `park`, `checkout`, `checkin`.**
Type them into the black **Terminal** window. A menu pops up — pick with the
arrow keys and press **Return**. That's the whole job.

> **Golden rule before park or checkin:** in Capture One, go
> **File → Close Session** first. If a session is still open, the command
> will stop and tell you to close it.

---

### 1. Done shooting? → `park`   *(only on the big Mac Studio "Versa")*

1. In Capture One: **File → Close Session.**
2. Click the Terminal window. Type: **`digi park`** and press Return.
3. Pick the session from the list. Pick **your name**.
4. Wait for it to finish. You'll see a green **✓ Parked.**

*The session is now on the Synology, waiting for someone to edit it.*

### 2. Ready to crop or QA? → `checkout`   *(on whichever mini you're sitting at)*

1. Type: **`digi checkout`** and press Return.
2. Pick a session from the list. Pick **your name**.
3. Wait for the green **✓ Checked out.** It prints a folder path — that path
   is on the fast SSD attached to this mini.
4. In Capture One: **File → Open Session…** and open it **from that exact
   path**. **Never open a session from the Synology.**

*Now it's yours. Nobody else can grab it until you check it back in.*

### 3. Done, or stopping for the day? → `checkin`   *(same mini you checked out on)*

1. In Capture One: **File → Close Session.**
2. Type: **`digi checkin`** and press Return.
3. Pick what you did — **crop**, **qa-qc**, **done**, or **other**.
4. Type a short note (e.g. "cropped half, needs QA"). Press Return.
5. Wait for the green **✓ Checked in.**

*It's back on the Synology for the next person.*

---

### If you're not sure what's going on

| Type this      | It tells you                                  |
|----------------|-----------------------------------------------|
| `digi queue`   | Every session and who has it                   |
| `digi status`  | What **you** have out and where                |
| `digi log`     | The last few things everyone did               |

### The four things that cause all the trouble — don't do them

1. **Don't** run `park`/`checkin` with the session still open in Capture One.
2. **Don't** open a session straight from the Synology. Always `checkout` first.
3. **Don't** delete anything on the Synology. Ever.
4. **Don't** push through a red error message. **Stop and get John.**

> **See red text?** Read the first line — it usually says exactly what to fix.
> If it mentions a **"packed (.eip)"** session, or anything you don't
> understand: **stop and get John.** A 5-minute "is this normal?" beats a
> 5-hour recovery.

---
*Full details: `docs/SOP-capture-one-handoff.md`. Pinned copy is by the minis.*
