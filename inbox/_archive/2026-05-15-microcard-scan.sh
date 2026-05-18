#!/usr/bin/env bash
# Scan microcard scans for card-ID labels (Fo-54 + 4-digit number).
# Outputs CSV: filename,card_id (blank if not a cover frame)
set -uo pipefail  # no -e: tesseract/grep may legitimately fail per-frame

SRC="${1:-/Users/jmpike/Pictures/Microscopical_Study/Output/Micoscopical_2}"
OUT="${2:-/tmp/microcard-ids.csv}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "filename,card_id,raw" > "$OUT"
count=0
for f in "$SRC"/*.jpg; do
  count=$((count+1))
  base=$(basename "$f")
  found=""
  raw=""
  # Try a few preprocessings — covers have huge labels rotated 90°.
  for rot in 90 -90; do
    for thr in 50 60 70; do
      magick "$f" -rotate $rot -threshold ${thr}% "$TMP/p.png" 2>/dev/null
      txt=$(tesseract "$TMP/p.png" - --psm 6 2>/dev/null | tr -d '\r')
      # Look for the 4-digit ID — it appears near "Fo-54" or "MICRO CARD"
      if echo "$txt" | grep -qiE 'fo[- ]?54|micro[ ]?card'; then
        id=$(echo "$txt" | grep -oE '\b[0-9]{4}\b' | head -1)
        if [[ -n "$id" ]]; then
          found="$id"
          raw=$(echo "$txt" | tr '\n' ' ' | tr -s ' ' | head -c 200)
          break 2
        fi
      fi
    done
  done
  printf '%s,%s,"%s"\n' "$base" "$found" "${raw//\"/\'}" >> "$OUT"
  if (( count % 20 == 0 )); then echo "  ... $count files scanned" >&2; fi
done
echo "Done. Results: $OUT" >&2
