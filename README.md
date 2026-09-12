# hyprmilk

![demo](demo.gif)

A Milk Outside A Bag Of Milk themed desktop shell for Hyprland, written in QML
on [Quickshell](https://quickshell.org). Everything you see comes out of the
actual game: the bedroom, the girl, her dialogue, the sounds she mutters while
text scrolls by.

## How the wallpaper works

The wallpaper is layered the same way the game layers its scenes. Behind
everything sits a red-dominant image, a CG or one of the painted sky frames.
In front of it is the room plate, drawn mostly in grey and black, with its
window cutouts punched out as transparent areas. The red stuff only peeks
through the windows, which is how the original scenes were composited.
`SUPER+W` cycles that back layer with a 700ms crossfade.

Milk-Chan stands in the corner. She blinks, breathes, and her mouth moves
while dialogue text is on screen. Click her or anywhere on the wallpaper and
she cycles through poses and emotions. Left alone she drifts into new moods
every minute or two. The layers track your cursor at different depths, and
she leans and squashes a little when you look up or down at her.

Focus a window and the whole scene freezes in place, parallax, breathing,
blinks and all. Focus the desktop again and it eases back to life.

## Dialogue

Lines come from the game's English translation, typed out in the game's own
font in milk red, with the game's talking loop playing while the text
reveals. The loop starts when a line appears and fades when the typing
finishes, at the game's own 20 characters per second. Lines show up on
demand with `SUPER+X`, on a timer every few minutes, and the first time you
enter each room. Clicking the textbox skips the typewriter, clicking again
dismisses it.

## The bar

The bar is drawn from the game's UI kit, dark segments with wobbly
hand-drawn red frames. Workspace chips are per monitor and come straight
from the workspace rules in your hyprland config, so DP-3 shows 1 through 5
and DP-2 shows 6 through 10 here. Chips with windows render solid, empty
ones render hollow, the active one lights up red. There is a clock, volume,
a voice toggle for Milk-Chan, a control center button, and a music segment
that appears when something is playing, fed by MPRIS, with the in-game
radio built in.

## Control center

`SUPER+Q` opens it. Volume and brightness sliders, power actions (lock,
sleep, logout, reboot, shutdown), a calendar, and a small CPU and RAM
readout, all in the same red frame style. Volume and brightness OSDs pop up
when you change them.

## Keybinds

| Key | Action |
| --- | --- |
| `SUPER+SPACE` | App launcher (also wallpaper, Milk-Chan, talk, radio actions) |
| `SUPER+N` | Notification center |
| `SUPER+Q` | Control center |
| `SUPER+W` | Cycle the background layer |
| `SUPER+G` | Toggle Milk-Chan |
| `SUPER+X` | Show a dialogue line |

Clicking the wallpaper or Milk-Chan cycles her pose and emotion.

## Install

You need Hyprland, Quickshell 0.3.x, mpv, ffmpeg for the asset pipeline, and
a copy of Milk Outside A Bag Of Milk. The shell reads only rips, never the
game install itself.

```sh
./tools/extract.sh /path/to/steamapps/common/Milk\ outside\ a\ bag\ of\ milk\ outside\ a\ bag\ of\ milk
python3 tools/dialogue.py
python3 tools/gen_bindings.py
python3 tools/gen_manifests.py
./tools/install.sh
```

`extract.sh` rips and curates the game archive with unrpa. `dialogue.py`
compiles the scripts and translations into `data/*.js`. `gen_bindings.py`
reads your workspace rules so the bar chips match your monitors.
`gen_manifests.py` inventories sprites, radio and the wallpaper pool, and
slices the hand-drawn frame used for every outline. `install.sh` symlinks
the shell into `~/.config/quickshell/hyprmilk`, installs the Retro Gaming
font, wires the autostart line and keybinds into `hyprland.lua`, and drops a
matching hyprlock theme.

Then relog, or start `qs -c hyprmilk -n` by hand.

## Notes

Game audio routes through mpv. The talking loop and click sounds are on by
default. Room ambience is wired but switched off at the master switch in
`Sfx.qml`, flip `ambientEnabled` if you want it back.

The shell talks to the Hyprland socket directly for workspace jumps, since
the hyprlua shim mangles bare dispatch strings. Everything here is Arch
tested at Quickshell 0.3.1 across three monitors, one of them HDR.

Game assets are rips and stay out of git. The repo carries the shell, tools
and data modules only.
