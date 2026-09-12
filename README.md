# hyprmilk 🥛

![demo](demo.gif)

A Milk Outside A Bag Of Milk themed desktop shell for Hyprland, written in QML
on [Quickshell](https://quickshell.org). Everything you see comes out of the
actual game: the bedroom, the girl, her dialogue, the sounds she mutters while
text scrolls by.

## Features

- **Layered wallpaper** — a red-dominant game image (CG or painted sky frame)
  shows through the transparent windows of the room plate, exactly like the
  game's own compositing. Cycle it with `SUPER+W` (700ms crossfade).
- **Milk-Chan** — animated sprite rig with blinks, breathing, talking mouth
  and idle mood swings. Click her or the wallpaper to cycle poses and
  emotions. She leans with your cursor (per-layer depth parallax) and her feet
  stay planted.
- **Dialogue** — lines from the game's English translation, typewriter reveal
  in the game's font at 20 cps, with the game's own `narr.ogg` talking loop.
  Click once to skip, again to dismiss. Also fires on room entry and every
  few minutes.
- **Top bar** — per-monitor workspace chips parsed from your hyprland config
  (solid = occupied, hollow = empty, red = active), clock, volume, voice
  mute, power, control center, and an MPRIS music segment with the in-game
  radio.
- **Control center** (`SUPER+Q`) — volume and brightness sliders, power
  actions (lock / sleep / logout / reboot / off), calendar, CPU and RAM
  readout.
- **Launcher** (`SUPER+SPACE`) — app search plus shell actions (switch
  wallpaper, toggle Milk-Chan, talk, radio).
- **Notifications, volume OSD, lock screen theme** — all in the same
  hand-drawn red frame style.

## Keybinds

| Key | Action |
|---|---|
| `SUPER+SPACE` | App launcher |
| `SUPER+N` | Notification center |
| `SUPER+Q` | Control center |
| `SUPER+W` | Cycle the background layer |
| `SUPER+G` | Toggle Milk-Chan |
| `SUPER+X` | Show a dialogue line |

Clicking the wallpaper or Milk-Chan cycles her pose and emotion. Clicking the
textbox skips the typewriter, then dismisses it.

## Background mode

Focus a window and the wallpaper freezes in place: parallax holds, breathing
pauses, blinks stop, the ambience timer skips. Focus the desktop again and
everything eases back to life. This is derived from Hyprland's active toplevel,
so it works even when moving to an empty workspace on another monitor.

## Requirements

- Hyprland
- [Quickshell](https://quickshell.org) 0.3.x
- mpv (audio)
- A copy of Milk Outside A Bag Of Milk (for the asset pipeline)
- ffmpeg, python3 (pipeline)

## Install

```sh
./tools/extract.sh /path/to/steamapps/common/Milk\ outside\ a\ bag\ of\ milk\ outside\ a\ bag\ of\ milk
python3 tools/dialogue.py
python3 tools/gen_bindings.py
python3 tools/gen_manifests.py
./tools/install.sh
```

`extract.sh` rips and curates the game archive with unrpa (sprites, walls,
radio, fonts, GUI kit). `dialogue.py` compiles the scripts and translations
into `data/*.js`. `gen_bindings.py` reads your workspace rules so the bar
chips match your monitors. `install.sh` symlinks the shell into
`~/.config/quickshell/hyprmilk`, installs the Retro Gaming font, wires the
autostart line and keybinds into `hyprland.lua`, and drops a matching hyprlock
theme.

Then relog, or start `qs -c hyprmilk -n` by hand.

## Notes

- Game audio (talking loop, click blips, radio) is on. Room ambience is wired
  but off at the master switch (`ambientEnabled` in `Sfx.qml`).
- The shell talks to the Hyprland socket directly for workspace jumps, since
  the hyprlua shim mangles bare dispatch strings.
- Game assets are rips and stay out of git (`assets/` is ignored). The repo
  carries the shell, tools and data modules only.
- Tested on Arch, Quickshell 0.3.1, three monitors including one HDR display.
