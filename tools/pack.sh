#!/usr/bin/env bash
# pack the shell + ripped game assets into a single portable archive.
# the result unpacks to a fully working checkout: run tools/install.sh there.
# usage: tools/pack.sh [outfile]   (default: hyprmilk-portable.tar.gz)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/hyprmilk-portable.tar.gz}"

[ -d "$ROOT/assets" ] || { echo "!! no assets/ — run tools/extract.sh first" >&2; exit 1; }

# build OUTSIDE the tree we are archiving, then move in (tar chokes when the
# archive grows inside the folder it is reading)
TMP_OUT="$(mktemp -u /tmp/hyprmilk-portable.XXXXXX.tar.gz)"

tar -czf "$TMP_OUT" \
    -C "$(dirname "$ROOT")" \
    --exclude="$(basename "$ROOT")/.git" \
    --exclude="$(basename "$ROOT")/tools/__pycache__" \
    --exclude="$(basename "$ROOT")/hyprmilk-portable.tar.gz" \
    "$(basename "$ROOT")"

mv "$TMP_OUT" "$OUT"

SIZE=$(du -h "$OUT" | cut -f1)
echo ">> packed: $OUT ($SIZE)"
echo ">> unpack elsewhere, then: tools/install.sh && qs -c hyprmilk -n"
