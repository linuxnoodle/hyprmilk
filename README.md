# hyprmilk 🥛

A Milk Outside A Bag Of Milk visual-novel themed desktop shell for Hyprland,
written in QML on [Quickshell](https://quickshell.org). Game art, dialogue and
sound are ripped straight from the VN.

## Requirements

- Hyprland (wayland compositor)
- Quickshell 0.3.x (Arch: `quickshell`)
- mpv (audio engine; `Sfx.enabled = false` disables it)
- The game's assets pipeline (below) — no game install needed at runtime

## Install

```sh
# 1. rip + curate assets (needs the Steam install path; ~2 min, 90 MB result)
./tools/extract.sh /path/to/game/dir          # default: SteamLibrary path
python3 tools/dialogue.py
python3 tools/gen_bindings.py                 # workspace rules from your hyprland.lua
python3 tools/gen_manifests.py                # sprites/walls/radio, also slices frame9

# 2. symlink into quickshell + install font + patch hyprland.lua autostart
./tools/install.sh
```

Then restart the Hyprland session (or `hyprctl reload`) — `hyprland.lua`
starts `qs -c hyprmilk` on login. A lock screen theme for hyprlock is written
to `~/.config/hypr/hyprlock.conf` by `install.sh`… apply it by hand if you
already have a custom one.

## Keybinds (added by install.sh)

| Key | Action |
|---|---|
| `SUPER+SPACE` | App launcher (also: Switch wallpaper, Toggle Milk-Chan, Talk, radio…) |
| `SUPER+N` | Notification center |
| `SUPER+W` | Cycle the background layer (sky frames / CGs behind the room windows) |
| `SUPER+G` | Toggle Milk-Chan |
| `SUPER+X` | Show a dialogue line |
| `SUPER+Q` | Control center (volume/brightness sliders, power, calendar) |
| `SUPER+N` | Notification center |
| `SUPER+G` | Toggle Milk-Chan |
| `SUPER+T` `SUPER+E` etc. | your existing binds, untouched |

## What it does

- **Layered wallpaper**: the red-dominant game imagery (CGs / sky frames)
  shows through the transparent windows of the room plate (`bg.png`) —
  cycle with `SUPER+W`.
- **Background mode**: focus a window and the wallpaper freezes (parallax
  holds, breathing/blinks pause, ambience silent); focus the desktop again
  and everything eases back in.
- **Milk-Chan**: animated sprite rig (blinks, talks while text is on screen,
  pose/emotion cycle on idle; click the wallpaper to change her).
- **Dialogue**: game lines, typewriter reveal, Retro Gaming font in milk red;
  periodic line every 4 min + on demand (`SUPER+X`). Renders below windows.
- **Top bar**: workspace chips bound per monitor (parsed from your
  `hyprland.lua` rules), clock, volume, voice-mute, power; stylized game
  outline on every surface.
- **Launcher / notifications / OSD / music player** (MPRIS + in-game radio).

## Layout

```
shell.qml, Theme/RoomState/Ui/Music/Sfx/Cursor.qml  — root singletons
bar/  bg/  dialogue/  launcher/  music/  notifs/  osd/  widgets/
assets/             game rips (gitignored):
  bg/{bg.png, walls/}   sprites/  gui/{frame.png, frame9/}
  audio/{radio, ui}/    fonts/game-122.ttf (Retro Gaming)
data/*.js           compiled data modules (rooms, dialogue, manifest, walls)
tools/              asset + data pipeline, installer
```

## Notes / known states

- Game audio is **off** by default: `Sfx.enabled = false` in `Sfx.qml` (sfx,
  voices, room ambience all route through mpv; ambience has a slow
  focus-based fade-in that was disabled with the master switch).
- The 85-frame skybox animation and per-room scene switching were folded into
  the static layered wallpaper to avoid the "flashing" you hit earlier.
- `wm/WindowFrames.qml` (PNG window outlines) was removed — Hyprland's native
  milk-red borders are used instead.