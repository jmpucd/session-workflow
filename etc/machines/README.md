# Per-machine overrides (optional)

Most Macs need **no file here**. Every default — session paths, the Synology
mount and queue — lives in `etc/shared/defaults.yaml`, and `digi` works
straight after `./install.sh`.

Only a machine that differs gets `etc/machines/<name>.yaml`, containing just
the differing keys. Today that's an edit mini whose working sessions live on a
TB SSD:

```
./install.sh --local-working /Volumes/Edit_SSD/capture_sessions
```

which writes (see `_example.yaml`):

```yaml
paths:
  local_working: "/Volumes/Edit_SSD/capture_sessions"
```

A key in the machine file wins; anything it omits falls back to the defaults.
What a machine can do depends only on which paths are set: `capture_root` for
`digi park`/presync, `local_working` for `checkout`/`checkin`.

The name comes from the gitignored `etc/machine-name` file, written by
`install.sh` when it creates an override file (defaulting to the Sharing-pane
"Local hostname"). It deliberately does NOT use `hostname -s`: on a Mac with
no pinned HostName that value follows the network (e.g. `Mac` at home,
`n99248c` on campus). To rename a machine, edit `etc/machine-name` and rename
its YAML to match. `DIGI_MACHINE=<name>` overrides everything for a one-off run.

## Conventions

- Keep secrets OUT of these files. Use SSH key auth for remotes; put any
  tokens/passwords in `etc/secrets/` (gitignored).
- After editing, commit the change so other machines see what their peers
  look like (helpful for debugging).
