#!/usr/bin/env bash
# hyprmilk asset pipeline: extract game RPA -> curate -> assets/
# Usage: tools/extract.sh [game_dir] [work_dir]
#   game_dir: Steam install of "Milk outside a bag of milk outside a bag of milk"
#             (default: /mnt/SteamLibrary/steamapps/common/Milk outside a bag of milk outside a bag of milk)
#   work_dir: scratch space for full extraction (default: /tmp/pmkm2-extract)
set -euo pipefail

GAME_DIR="${1:-/mnt/SteamLibrary/steamapps/common/Milk outside a bag of milk outside a bag of milk}"
WORK_DIR="${2:-/tmp/pmkm2-extract}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/assets"

# ---------------------------------------------------------------- unrpa
if [ ! -f "$WORK_DIR/images/bg.png" ]; then
    echo ">> extracting RPA archive (675 MB, takes a bit)..."
    if [ ! -x /tmp/rpatool-venv/bin/python ]; then
        python3 -m venv /tmp/rpatool-venv
        /tmp/rpatool-venv/bin/pip install -q unrpa
    fi
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    /tmp/rpatool-venv/bin/python -m unrpa -m -p . "$GAME_DIR/game/archive.rpa"
else
    echo ">> using existing extraction at $WORK_DIR"
fi

[ -f "$WORK_DIR/images/bg.png" ] || { echo "!! extraction incomplete: no images/bg.png" >&2; exit 1; }

# ---------------------------------------------------------------- curation
G="$WORK_DIR"   # game files
A="$ASSETS"

rm -rf "$A"
mkdir -p "$A"/{bg/skybox,bg/mirror,rooms/hub,sprites,gui,audio/rooms,audio/radio,audio/ui,fonts,data}

# -- background layers (room plate / skybox / girl's mirror reflection)
cp "$G/images/bg.png"                "$A/bg/bg.png"
cp "$G/images/skybox/"*.png          "$A/bg/skybox/"
cp "$G/images/cg_mirror/cg_mirror_gg/"*.png "$A/bg/mirror/"

# -- point-and-click room plates
for r in zerk lest magaz telef kompol; do
    mkdir -p "$A/rooms/$r"
    cp "$G/images/str/$r/"*.png "$A/rooms/$r/"
done
# bedroom hub scene uses bg.png + sky2; keep a couple of CG extras
cp "$G/images/mini_cg_door/"*.png    "$A/rooms/hub/" 2>/dev/null || true

# -- sprite rig: poses x emotions, layered (body / eyes / mouth)
cp -r "$G/images/sprites/"*          "$A/sprites/"

# -- GUI kit (9-slice frames, buttons, sliders)
for f in frame.png menu.png main_menu.png; do
    cp "$G/gui/$f" "$A/gui/" 2>/dev/null || true
done
# red layering art: NVL narrator veil + overlay lit/unlit regions (behind windows)
for f in nvl.png overlay.png overlay_invert.png; do
    cp "$G/images/$f" "$A/gui/" 2>/dev/null || true
done
cp -r "$G/gui/bar" "$G/gui/button" "$G/gui/slider" "$G/gui/overlay" "$A/gui/" 2>/dev/null || true

# -- audio: room ambients, radio stations, UI sounds
for r in zerk lest magaz telef kompol; do
    mkdir -p "$A/audio/rooms/$r"
    cp "$G/audio/$r/"*.mp3 "$G/audio/$r/"*.ogg "$A/audio/rooms/$r/" 2>/dev/null || true
done
# bedroom hub music lives in audio/milk/
mkdir -p "$A/audio/rooms/hub"
cp "$G/audio/milk/"*.mp3 "$A/audio/rooms/hub/"
for st in radio1 radio2 radio3; do
    mkdir -p "$A/audio/radio/$st"
    cp "$G/audio/radio/$st/"* "$A/audio/radio/$st/"
done
mkdir -p "$A/audio/ui"
cp "$G/audio/nice sounds/"*.ogg "$A/audio/ui/"
for f in Button1.mp3 Button2.mp3 no.ogg clock.ogg narr.ogg narrz.ogg start.mp3; do
    cp "$G/audio/$f" "$A/audio/ui/" 2>/dev/null || true
done
# phone typing / message sounds
cp "$G/audio/telef/send.ogg" "$G/audio/telef/recieve.ogg" "$A/audio/ui/" 2>/dev/null || true

# -- fonts
cp "$G/images/122.ttf" "$A/fonts/game-122.ttf"
cp "$G/images/aaa.ttf" "$A/fonts/game-aaa.ttf"

echo ">> curated assets:"
du -sh "$A"/*
echo ">> done."
