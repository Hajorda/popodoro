#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

# Regenerate background (in case colors or text changed)
python3 make_background.py

# Install appdmg if missing
if ! command -v appdmg &>/dev/null; then
  echo "Installing appdmg..."
  npm install -g appdmg
fi

OUT="Popodoro.dmg"
rm -f "$OUT"
appdmg popodoro.json "$OUT"
echo "Done → $(pwd)/$OUT"
