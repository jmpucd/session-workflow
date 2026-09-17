#!/usr/bin/env bash
# lib/machine-name.sh — resolve a STABLE name for this machine.
#
# `hostname -s` is not usable on macOS: when no HostName is pinned via scutil,
# macOS derives it from the current network's DHCP/reverse-DNS, so the same
# Mac reports "Mac" at home and "n99248c" on campus. Naming the per-machine
# config after it means digi "loses" its config whenever the network changes.
#
# Resolution order (first non-empty wins):
#   1. $DIGI_MACHINE            — explicit override for one-off runs/testing
#   2. etc/machine-name         — gitignored file written by install.sh on first
#                                 run; this is what pins the name for good
#   3. scutil --get LocalHostName — the Sharing-pane name; stable across networks
#   4. hostname -s              — last resort (non-macOS)
#
# Usage: source this file, then: name="$(digi_machine_name "$ETC_DIR")"
digi_machine_name() {
  local etc_dir="$1" name=""
  if [[ -n "${DIGI_MACHINE:-}" ]]; then
    name="$DIGI_MACHINE"
  elif [[ -s "$etc_dir/machine-name" ]]; then
    name="$(head -n1 "$etc_dir/machine-name")"
  elif command -v scutil >/dev/null 2>&1; then
    name="$(scutil --get LocalHostName 2>/dev/null || true)"
  fi
  [[ -n "$name" ]] || name="$(hostname -s)"
  # Sanitize: the name becomes a filename.
  name="${name//[^A-Za-z0-9._-]/-}"
  printf '%s\n' "$name"
}

# Which of the sources above produced the name — for `digi doctor`.
digi_machine_name_source() {
  local etc_dir="$1"
  if [[ -n "${DIGI_MACHINE:-}" ]]; then echo '$DIGI_MACHINE'
  elif [[ -s "$etc_dir/machine-name" ]]; then echo "$etc_dir/machine-name"
  elif command -v scutil >/dev/null 2>&1 && [[ -n "$(scutil --get LocalHostName 2>/dev/null || true)" ]]; then echo 'scutil LocalHostName'
  else echo 'hostname -s'
  fi
}
