#!/usr/bin/env bash
# hyprmilk install: symlink shell into quickshell config dir + patch hyprland.lua
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1. quickshell config dir (qs -c hyprmilk)
mkdir -p "$HOME/.config/quickshell"
ln -sfn "$ROOT" "$HOME/.config/quickshell/hyprmilk"
echo ">> linked $HOME/.config/quickshell/hyprmilk -> $ROOT"

# 2. verify data modules exist (dialogue/manifest/rooms)
for f in data/dialogue.js data/manifest.js data/rooms.js; do
    [ -f "$ROOT/$f" ] || { echo "!! missing $ROOT/$f — run tools/extract.sh + tools/dialogue.py + tools/gen_manifests.py first" >&2; exit 1; }
done

# 3. hyprland.lua: make it exec qs on start (idempotent guard)
LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$LUA" ] && ! grep -q 'qs -c hyprmilk' "$LUA"; then
    sed -i 's|    hl.exec_cmd("waybar")|    hl.exec_cmd("qs -c hyprmilk -n")\n    hl.exec_cmd("waybar")|' "$LUA"
    echo ">> added qs -c hyprmilk to hyprland.lua startup"
else
    echo ">> hyprland.lua already wires up hyprmilk (or missing)"
fi

echo ">> done. reload Hyprland (hyprctl reload) or restart session."