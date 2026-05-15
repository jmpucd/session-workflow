# Per-machine config

Each Mac that runs `digi` gets a YAML file here named after its short hostname:

```
etc/machines/<hostname>.yaml
```

`install.sh` creates one from `_template.yaml` on first run. Edit it to match
the machine's role and paths.

## Conventions

- Keep secrets OUT of these files. Use SSH key auth for remotes; put any
  tokens/passwords in `etc/secrets/` (gitignored).
- If a value differs per-user on a shared machine, create
  `etc/machines/<hostname>.local.yaml` (gitignored) — `digi` will merge it
  over the tracked file.
- After editing, commit the change so other machines see what their peers
  look like (helpful for debugging).
