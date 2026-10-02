#!/bin/bash
set -euo pipefail

OUT="Resources/StarterLibrary"
rm -rf "$OUT"
mkdir -p "$OUT"

magick -size 1024x1365 plasma:fractal \
  -colorspace sRGB \
  -blur 0x1 \
  -sigmoidal-contrast 5,50% \
  -fill '#18d4ff' -colorize 8 \
  "$OUT/Aurora-Night.png"

magick -size 1024x1365 plasma:fractal \
  -colorspace sRGB \
  -blur 0x1 \
  -sigmoidal-contrast 5,50% \
  -fill '#8b5cf6' -colorize 8 \
  "$OUT/Ultraviolet-Glass.png"

cat > "$OUT/index.json" <<'JSON'
{
  "version": 1,
  "title": "Tendies Studio Starter Library",
  "items": [
    { "file": "Aurora-Night.png", "title": "Aurora Night", "category": "Abstract" },
    { "file": "Ultraviolet-Glass.png", "title": "Ultraviolet Glass", "category": "Abstract" }
  ]
}
JSON
