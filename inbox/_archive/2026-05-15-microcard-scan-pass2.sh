#!/usr/bin/env bash
# Second-pass OCR with more preprocessing variants for frames missed by first pass.
set -uo pipefail
SRC="/Users/jmpike/Pictures/Microscopical_Study/Output/Micoscopical_2"
IN="/tmp/microcard-ids.csv"
OUT="/tmp/microcard-ids-pass2.csv"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

cp "$IN" "$OUT"

# Get list of files with no ID yet
empties=$(awk -F, 'NR>1 && $2==""{print $1}' "$IN")
count=0
for base in $empties; do
  count=$((count+1))
  f="$SRC/$base"
  found=""
  # More aggressive: try -level stretching, contrast boost, different psms
  for rot in 90 -90; do
    for opts in \
      "-rotate $rot -resize 200% -threshold 60%" \
      "-rotate $rot -level 10%,80% -threshold 50%" \
      "-rotate $rot -auto-level -threshold 55%" \
      "-rotate $rot -negate -threshold 40% -negate"; do
      magick "$f" $opts "$TMP/p.png" 2>/dev/null
      for psm in 6 11 12; do
        txt=$(tesseract "$TMP/p.png" - --psm $psm 2>/dev/null | tr -d '\r')
        if echo "$txt" | grep -qiE 'fo[- ]?54|micro[ ]?card'; then
          id=$(echo "$txt" | grep -oE '\b[83][0-9]{3}\b' | head -1)
          if [[ -n "$id" ]]; then
            found="$id"
            break 3
          fi
        fi
      done
    done
  done
  if [[ -n "$found" ]]; then
    # Update CSV in place
    sed -i '' "s|^${base},,|${base},${found},|" "$OUT"
    echo "  FOUND: $base → $found" >&2
  fi
  if (( count % 30 == 0 )); then echo "  ... checked $count empties" >&2; fi
done
echo "Done. Results: $OUT" >&2
