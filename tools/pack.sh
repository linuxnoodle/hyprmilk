#!/usr/bin/env bash
# pack the shell + ripped game assets into a single portable archive.
# the result unpacks to a fully working checkout: run tools/install.sh there.
# usage: tools/pack.sh [outfile]   (default: hyprmilk-portable.tar.gz)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/hyprmilk-portable.tar.gz}"

[ -d "$ROOT/assets" ] || { echo "!! no assets/ — run tools/extract.sh first" >&2; exit 1; }

tar -czf "$OUT" \
    -C "$(dirname "$ROOT")" \
    --exclude="$(basename "$ROOT")/.git" \
    --exclude="$(basename "$ROOT")/tools/__pycache__" \
    "$(basename "$ROOT")"

SIZE=$(du -h "$OUT" | cut -f1)
echo ">> packed: $OUT ($SIZE)"
echo ">> unpack elsewhere, then: tools/install.sh && qs -c hyprmilk -n"
