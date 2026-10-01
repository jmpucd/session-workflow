# digi-presync launchd agent (capture station only)

Runs `digi presync` every 60 seconds in the background, so raw capture
files start moving to the Synology while a session is still being shot —
see `docs/capture-one-workflow.md` for what presync actually does and why.
Only needed on the capture station (Versa); other machines don't run it.

## Install

```sh
cd ~/code/digitization-tasks-helper/etc/launchd
sed "s|__HOME__|$HOME|g" edu.ucdavis.library.digi-presync.plist.template \
  > ~/Library/LaunchAgents/edu.ucdavis.library.digi-presync.plist
launchctl load ~/Library/LaunchAgents/edu.ucdavis.library.digi-presync.plist
```

Confirm it's running:

```sh
launchctl list | grep digi-presync
tail -f ~/Library/Logs/digi-presync.log
```

## Uninstall / pause

```sh
launchctl unload ~/Library/LaunchAgents/edu.ucdavis.library.digi-presync.plist
```

(Leaves the plist in place — `load` again to resume. `rm` the file too for
a full removal.)

## After a `git pull`

The installed plist is a static copy in `~/Library/LaunchAgents/`, not a
symlink — re-run the `sed` + `launchctl unload`/`load` above if this
template ever changes.

---

# digi-mount launchd agent (every machine that uses the Synology)

Runs `digi mount` every 2 minutes so the Synology share remounts on its own
after sleep or a network drop. It uses the password saved in the login
keychain — connect once in Finder (⌘K, `smb://DigiLab483.local/Digitization_Files`)
with **Remember this password** checked before installing.

## Install

```sh
cd ~/code/digitization-tasks-helper/etc/launchd
sed "s|__HOME__|$HOME|g" edu.ucdavis.library.digi-mount.plist.template \
  > ~/Library/LaunchAgents/edu.ucdavis.library.digi-mount.plist
launchctl load ~/Library/LaunchAgents/edu.ucdavis.library.digi-mount.plist
```

Check it: `tail ~/Library/Logs/digi-mount.log` (empty while the share stays
mounted). Uninstall: `launchctl unload` the plist, then `rm` it.
