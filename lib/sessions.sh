#!/usr/bin/env bash
# lib/sessions.sh — helpers for the Capture One session workflow.
# Sourced by digi-park, digi-checkout, digi-checkin, etc.
#
# Depends on lib/common.sh being sourced first (provides log/warn/err/die,
# machine_get, DIGI_HOSTNAME, DIGI_ETC_DIR).

# ---- shared defaults -------------------------------------------------------

DIGI_SHARED_DEFAULTS="${DIGI_ETC_DIR}/shared/defaults.yaml"
DIGI_SHARED_USERS="${DIGI_ETC_DIR}/shared/users.yaml"

shared_get() {
  local key="$1"
  [[ -f "$DIGI_SHARED_DEFAULTS" ]] || die "Missing $DIGI_SHARED_DEFAULTS"
  yq -r "$key // \"\"" "$DIGI_SHARED_DEFAULTS"
}

# Build the rsync argument list (flags + excludes) into a global array.
# Usage: rsync_args; rsync "${RSYNC_ARGS[@]}" src dst
rsync_args() {
  local flags
  flags="$(shared_get .rsync.flags)"
  [[ -n "$flags" ]] || flags="-ahP --info=stats2,progress2"
  # shellcheck disable=SC2206
  RSYNC_ARGS=( $flags )
  local p
  while IFS= read -r p; do
    [[ -n "$p" ]] && RSYNC_ARGS+=( --exclude="$p" )
  done < <(yq -r '.rsync.excludes[]? // empty' "$DIGI_SHARED_DEFAULTS")
}

# ---- path resolvers --------------------------------------------------------

# Path to the Synology session queue. Dies if not configured or not mounted.
synology_sessions_root() {
  local root
  root="$(machine_get .sessions.synology_root)"
  [[ -n "$root" ]] || die "sessions.synology_root not set in $DIGI_MACHINE_CONFIG"
  [[ -d "$root" ]] || die "Synology not mounted (or path wrong): $root"
  printf '%s\n' "$root"
}

# Local working dir for checked-out sessions. Dies if not configured.
local_working_root() {
  local root
  root="$(machine_get .paths.local_working)"
  [[ -n "$root" ]] || die "paths.local_working not set in $DIGI_MACHINE_CONFIG"
  # tilde expand
  root="${root/#\~/$HOME}"
  [[ -d "$root" ]] || die "local_working dir does not exist: $root (create it or fix the path)"
  printf '%s\n' "$root"
}

# Capture root on this machine (where Capture One puts new captures).
capture_root() {
  local root
  root="$(machine_get .paths.capture_root)"
  [[ -n "$root" ]] || die "paths.capture_root not set in $DIGI_MACHINE_CONFIG"
  root="${root/#\~/$HOME}"
  [[ -d "$root" ]] || die "capture_root does not exist: $root"
  printf '%s\n' "$root"
}

# ---- picker ----------------------------------------------------------------

# session_pick <parent-dir> <prompt>
# Prints chosen session name on stdout. Exits non-zero on cancel.
session_pick() {
  local parent="$1"
  local prompt="${2:-Pick a session}"

  local sessions=()
  local entry
  for entry in "$parent"/*/; do
    [[ -d "$entry" ]] || continue
    local name="${entry%/}"
    name="${name##*/}"
    # Skip dot/underscore prefixed (e.g. _digi)
    [[ "$name" == .* || "$name" == _* ]] && continue
    sessions+=( "$name" )
  done

  [[ ${#sessions[@]} -gt 0 ]] || die "No sessions found in $parent"

  if command -v fzf >/dev/null 2>&1; then
    local pick
    pick="$(printf '%s\n' "${sessions[@]}" | fzf --prompt="$prompt > " --height=40% --reverse)" \
      || die "Cancelled."
    printf '%s\n' "$pick"
  else
    PS3="$prompt > "
    local pick
    select pick in "${sessions[@]}"; do
      [[ -n "$pick" ]] || { echo "Pick a number." >&2; continue; }
      printf '%s\n' "$pick"
      return 0
    done
    die "Cancelled."
  fi
}

# ---- lock file -------------------------------------------------------------
#
# Lock lives at <synology_sessions_root>/<session>/.digi.lock.yaml.
# Format:
#   mac: mac-mini-edit-1
#   user: sam
#   local_path: /Volumes/Edit_SSD/capture_sessions/D-823
#   checked_out_at: 2026-05-17T18:30:12Z

lock_path() {
  local session="$1"
  printf '%s/%s/.digi.lock.yaml\n' "$(synology_sessions_root)" "$session"
}

lock_exists() {
  local session="$1"
  [[ -f "$(lock_path "$session")" ]]
}

# Print one field from the lock file (or empty if no lock / no field).
# Usage: lock_field <session> mac
lock_field() {
  local session="$1" field="$2"
  local p
  p="$(lock_path "$session")"
  [[ -f "$p" ]] || return 0
  yq -r ".${field} // \"\"" "$p"
}

# Atomic lock write. Dies if lock already exists held by a different mac.
# Usage: lock_write <session> <local_path> <user>
lock_write() {
  local session="$1" local_path="$2" user="$3"
  local p
  p="$(lock_path "$session")"
  local dir
  dir="$(dirname "$p")"
  [[ -d "$dir" ]] || die "Session dir missing on Synology: $dir"

  if [[ -f "$p" ]]; then
    local holder
    holder="$(yq -r '.mac // ""' "$p")"
    [[ "$holder" == "$DIGI_HOSTNAME" ]] || \
      die "Session is locked by $holder (since $(yq -r '.checked_out_at // "?"' "$p")). Refusing."
  fi

  local tmp
  tmp="$(mktemp "${dir}/.digi.lock.XXXXXX")"
  cat >"$tmp" <<EOF
mac: ${DIGI_HOSTNAME}
user: ${user}
local_path: ${local_path}
checked_out_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  mv -f "$tmp" "$p"
}

# Clear a lock. Refuses unless this mac holds it (override with force=1).
# Usage: lock_clear <session> [force]
lock_clear() {
  local session="$1" force="${2:-0}"
  local p
  p="$(lock_path "$session")"
  [[ -f "$p" ]] || { warn "No lock to clear for $session"; return 0; }
  if [[ "$force" != "1" ]]; then
    local holder
    holder="$(yq -r '.mac // ""' "$p")"
    [[ "$holder" == "$DIGI_HOSTNAME" ]] || \
      die "Lock is held by $holder, not this machine. Use 'digi force-unlock' if stale."
  fi
  rm -f "$p"
}

# ---- log -------------------------------------------------------------------
#
# Append-only JSONL at <synology_sessions_root>/_digi/log.jsonl.
# Each line: {"ts": "...", "action": "park|checkout|checkin|force-unlock",
#             "session": "...", "mac": "...", "user": "...", ... }

_log_file() {
  local root
  root="$(synology_sessions_root)"
  local dir="${root}/_digi"
  mkdir -p "$dir"
  printf '%s/log.jsonl\n' "$dir"
}

# log_event <action> <session> <user> [extra_json]
log_event() {
  local action="$1" session="$2" user="$3" extra="${4:-{}}"
  local logf
  logf="$(_log_file)"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local row
  row="$(
    jq -c -n \
      --arg ts "$ts" \
      --arg action "$action" \
      --arg session "$session" \
      --arg mac "$DIGI_HOSTNAME" \
      --arg user "$user" \
      --argjson extra "$extra" \
      '{ts:$ts, action:$action, session:$session, mac:$mac, user:$user} + $extra'
  )"
  printf '%s\n' "$row" >> "$logf"
}

# ---- Capture One safety ----------------------------------------------------

# Returns 0 if Capture One looks like it has *this* session open.
# Heuristics:
#   1. Capture One is running (pgrep), AND
#   2. The session has .cosessiondb-wal or -shm sidecar files (SQLite WAL).
# Either alone is too noisy on its own — combined they're a strong signal.
capture_one_busy() {
  local session_dir="$1"
  [[ -d "$session_dir" ]] || return 1

  # SQLite WAL/SHM sidecars = DB is open somewhere
  local has_wal=0
  shopt -s nullglob
  local f
  for f in "$session_dir"/*.cosessiondb-wal "$session_dir"/*.cosessiondb-shm; do
    has_wal=1; break
  done
  shopt -u nullglob

  [[ $has_wal -eq 1 ]] || return 1

  # Capture One process running on this machine
  pgrep -f "Capture One" >/dev/null 2>&1 || return 1

  return 0
}

assert_capture_one_idle() {
  local session_dir="$1"
  if capture_one_busy "$session_dir"; then
    die "Capture One looks like it has '$(basename "$session_dir")' open. Close the session (or quit Capture One) and try again."
  fi
}

# ---- who_am_i --------------------------------------------------------------

# Reads etc/shared/users.yaml, prompts for selection, prints chosen name.
who_am_i() {
  local users=()
  if [[ -f "$DIGI_SHARED_USERS" ]]; then
    local u
    while IFS= read -r u; do
      [[ -n "$u" ]] && users+=( "$u" )
    done < <(yq -r '.users[]? // empty' "$DIGI_SHARED_USERS")
  fi

  # Default suggestion is $USER
  local default="${USER:-unknown}"
  local i
  local found=0
  for i in "${users[@]}"; do
    [[ "$i" == "$default" ]] && { found=1; break; }
  done
  [[ $found -eq 1 ]] || users+=( "$default" )

  if command -v fzf >/dev/null 2>&1; then
    local pick
    pick="$(
      { printf '%s\n' "${users[@]}"; echo "(other — type a name)"; } \
      | fzf --prompt="Who are you? > " --height=30% --reverse
    )" || die "Cancelled."
    if [[ "$pick" == "(other"* ]]; then
      local typed
      read -r -p "Your name: " typed
      [[ -n "$typed" ]] || die "Empty name."
      warn "Consider adding '$typed' to $DIGI_SHARED_USERS"
      printf '%s\n' "$typed"
    else
      printf '%s\n' "$pick"
    fi
  else
    PS3="Who are you? > "
    local pick
    select pick in "${users[@]}" "(other — type a name)"; do
      if [[ "$pick" == "(other"* ]]; then
        local typed
        read -r -p "Your name: " typed
        [[ -n "$typed" ]] || { echo "Empty name." >&2; continue; }
        warn "Consider adding '$typed' to $DIGI_SHARED_USERS"
        printf '%s\n' "$typed"
        return 0
      elif [[ -n "$pick" ]]; then
        printf '%s\n' "$pick"
        return 0
      fi
    done
  fi
}

# ---- session size --------------------------------------------------------

# Pretty-print a session size: "54.1 GB, 1,204 files"
# Usage: session_size_pretty <session-dir>
session_size_pretty() {
  local d="$1"
  [[ -d "$d" ]] || { printf '?\n'; return; }
  # du -sh and find -type f for a quick approximation
  local size files
  size="$(du -sh "$d" 2>/dev/null | awk '{print $1}')"
  files="$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')"
  printf '%s, %s files\n' "$size" "$files"
}
