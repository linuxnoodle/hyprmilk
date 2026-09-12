#!/usr/bin/env bash
# hyprmilk install: symlink shell into quickshell config dir + patch hyprland.lua
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 1. quickshell config dir (qs -c hyprmilk)
mkdir -p "$HOME/.config/quickshell"
ln -sfn "$ROOT" "$HOME/.config/quickshell/hyprmilk"
echo ">> linked $HOME/.config/quickshell/hyprmilk -> $ROOT"

# 2. game font system-wide (family "Retro Gaming") — needs extract.sh run first
mkdir -p "$HOME/.local/share/fonts/hyprmilk"
if [ -f "$ROOT/assets/fonts/game-122.ttf" ]; then
    cp -f "$ROOT/assets/fonts/game-122.ttf" "$HOME/.local/share/fonts/hyprmilk/"
    fc-cache -f "$HOME/.local/share/fonts/hyprmilk" >/dev/null 2>&1
    echo ">> installed Retro Gaming font"
else
    echo "!! assets/ missing (no game rip) — run tools/extract.sh; skipping font install" >&2
fi

# 2. verify data modules exist (dialogue/manifest/rooms)
for f in data/dialogue.js data/manifest.js data/rooms.js; do
    [ -f "$ROOT/$f" ] || { echo "!! missing $ROOT/$f — run tools/extract.sh + tools/dialogue.py + tools/gen_manifests.py first" >&2; exit 1; }
done

# 3. workspace bindings (DP-3=1-5, DP-2=6-10, ...) from hyprland.lua
python3 "$ROOT/tools/gen_bindings.py" || true

# 3b. hyprlock theme (backup any existing config first)
LOCK="$HOME/.config/hypr/hyprlock.conf"
mkdir -p "$HOME/.config/hypr"
[ -f "$LOCK" ] && cp -f "$LOCK" "$LOCK.bak"
cp -f "$ROOT/tools/hyprlock.conf" "$LOCK"
echo ">> installed hyprlock theme ($LOCK, old config saved as hyprlock.conf.bak)"

# 4. hyprland.lua: exec qs on start, drop hyprpaper/hyprnotify/waybar
#    (shell IS the wallpaper + bar + notifications). Idempotent.
LUA="$HOME/.config/hypr/hyprland.lua"
if [ -f "$LUA" ]; then
    if ! grep -q 'qs -c hyprmilk' "$LUA"; then
        # anchor on the first remaining exec line in the autostart block
        sed -i 's|^\(    hl.exec_cmd("hypridle\( &\)\?"\))|    hl.exec_cmd("qs -c hyprmilk -n")\n\1|' "$LUA"
        echo ">> added qs -c hyprmilk to hyprland.lua startup"
    fi
    sed -i '/hl.exec_cmd("hyprpaper\( &\)\?")/d' "$LUA"
    # hyprmilk ships its own notification server — hyprnotify would hold the DBus name
    sed -i '/hl.exec_cmd("hyprnotify\( &\)\?")/d' "$LUA"
    # shell draws its own bar; waybar duplicates it
    sed -i '/hl.exec_cmd("waybar\( &\)\?")/d' "$LUA"
    echo ">> removed hyprpaper + hyprnotify + waybar from hyprland.lua startup"
else
    echo ">> hyprland.lua missing, skipping autostart patch"
fi

# 5. keybinds for the shell's IPC actions (idempotent via marker)
if [ -f "$LUA" ] && ! grep -q 'hyprmilk shell IPC' "$LUA"; then
    cat >> "$LUA" <<'EOF'

-- hyprmilk shell IPC (Quickshell IpcHandler target "shell")
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs -c hyprmilk ipc call shell toggleLauncher"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs -c hyprmilk ipc call shell toggleCenter"))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("qs -c hyprmilk ipc call shell toggleControl"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -c hyprmilk ipc call shell cycleWallpaper"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("qs -c hyprmilk ipc call shell toggleGirl"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("qs -c hyprmilk ipc call shell sayLine"))
EOF
    echo ">> added hyprmilk keybinds to hyprland.lua"
fi

echo ">> done. reload Hyprland (hyprctl reload) or restart session."