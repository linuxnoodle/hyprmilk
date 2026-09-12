#!/usr/bin/env bash
# pack the ripped GAME ASSETS into a shareable archive in the repo root.
# unpack with: tar xzf hyprmilk-game-assets.tar.gz --strip-components=1
#   (lands as assets/ + data/*.js next to the shell)
# usage: tools/pack.sh [outfile]   (default: hyprmilk-game-assets.tar.gz)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/hyprmilk-game-assets.tar.gz}"

[ -d "$ROOT/assets" ] || { echo "!! no assets/ — run tools/extract.sh first" >&2; exit 1; }

# build OUTSIDE the tree being archived, then move in
TMP_OUT="$(mktemp -u /tmp/hyprmilk-assets.XXXXXX.tar.gz)"

tar -czf "$TMP_OUT" \
    --transform "s|^|hyprmilk/|" \
    -C "$ROOT" assets data

mv "$TMP_OUT" "$OUT"

SIZE=$(du -h "$OUT" | cut -f1)
echo ">> packed: $OUT ($SIZE)"
echo ">> unpack next to the shell: tar xzf hyprmilk-game-assets.tar.gz"
