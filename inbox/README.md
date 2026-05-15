# inbox/

Scratch space for ad-hoc scripts and notes captured *while working*.

The rule: when you catch yourself doing the same thing twice, dump a copy of
the command(s) here with a short note. Don't polish. Don't worry about naming.
We promote inbox items into proper `bin/digi-*` commands during cleanup.

## Suggested filename pattern

```
YYYY-MM-DD-short-description.sh        # the script / commands
YYYY-MM-DD-short-description.md        # what you were trying to do, what
                                       # worked, what didn't, what's missing
```

Examples:

```
2026-05-15-rip-vhs-batch.sh
2026-05-15-rip-vhs-batch.md
2026-05-16-fix-c1-session-permissions.sh
```

## How to dump quickly

From any terminal on any machine:

```bash
cd ~/code/digitization-tasks-helper/inbox
$EDITOR "$(date +%Y-%m-%d)-thing-im-doing.sh"
```

Or paste a chat session / Claude transcript into a `.md` file — that counts too.
