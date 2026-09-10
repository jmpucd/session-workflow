# Per-machine config

Each Mac that runs `digi` gets a YAML file here named after its short hostname:

```
etc/machines/<hostname>.yaml
```

`install.sh` creates one from `_template.yaml` on first run. Edit it to match
the machine's paths.

## `role:` is a label, not a restriction

The `role` field (capture | edit | laptop | nas | server) is informational
only — `digi doctor` prints it, and nothing else in the codebase reads it.
What a machine can actually do is determined purely by which `paths.*`
fields are filled in: set `capture_root` and `digi park` works; set
`local_working` and `digi checkout`/`checkin` work. Fill in both if a
machine genuinely does both (a capture station that also edits locally,
an edit machine that occasionally captures) — there's no exclusive
category forcing a choice.

## Conventions

- Keep secrets OUT of these files. Use SSH key auth for remotes; put any
  tokens/passwords in `etc/secrets/` (gitignored).
- If a value differs per-user on a shared machine, create
  `etc/machines/<hostname>.local.yaml` (gitignored) — `digi` will merge it
  over the tracked file.
- After editing, commit the change so other machines see what their peers
  look like (helpful for debugging).
