These are the working notes from building the shell, kept around because the
reasons behind a few odd choices aren't obvious from the code. The short
version of the story: the shell started as a flat wallpaper with a girl on it,
then grew into a layered scene that behaves like the game's own compositing.

The wallpaper is three layers deep. At the bottom sits a red-dominant image,
one of the game's CGs or a painted sky frame. Above it is the room plate,
bg.png, drawn in grey and black with the window areas punched out as
transparent pixels. The room plate hides most of the lower layer, and the red
imagery only shows through the window cutouts, which is the whole look. Each
layer is oversized by about fourteen percent of the screen width so cursor
parallax never reveals an edge, and each one carries its own depth. The room
plate moves at rate one, the background at roughly half that, and Milk-Chan at
1.6 since she's the closest thing to the viewer. Vertical movement on her is a
lean and squash warp rather than a translation, so her feet stay planted while
she seems to tilt with your cursor. The offsets are smoothed with an
underdamped spring, which is what gives quick cursor sweeps their little
overshoot and settle.

Milk-Chan is built the way the game builds her, as a LiveComposite of three
layers. A body frame picked by pose and emotion, an eye overlay that blinks on
the game's timing, open for two to six seconds, then a quick half and closed
blink, and a mouth layer that alternates half and full frames while she
speaks. The source paths are computed from the manifest with fallbacks, since
some emotions ship without their own flap frames and fall back to the neutral
emotion's mouth the same way the game falls back. Changing her pose used to
crossfade through a ghost of the old frame, but the dip read as her vanishing,
so now she swaps instantly. Idle mood reseeds happen every forty five to one
hundred fifty seconds and never interrupt a line mid-speech.

Dialogue comes from the game's English translation, compiled out of the
Ren'Py sources into static JS modules the shell imports at load. The talking
sound is the game's own narr.ogg, looped from the moment a line appears and
faded when the typewriter completes, which mirrors the callback protocol in
the original scripts. The typewriter runs at the game's twenty characters per
second. Lines fire on demand, on a four minute timer, and the first time you
enter a room. The textbox renders below windows since a textbox buried behind
a browser is worse than no textbox.

The bar chips are bound per monitor. The bindings are parsed out of
hyprland.lua by tools/gen_bindings.py, so DP-3 shows one through five, DP-2
shows six through ten and DP-1 shows eleven through fifteen. A chip is solid
when its workspace has windows and hollow when it's empty, and the occupancy
comes from polling hyprctl through a unique temp file per query, because
FileView refuses to reload a path it has already seen.

Background mode exists because wallpaper motion behind a focused window is
noise. When a window has focus the parallax target freezes at its last value,
breathing pauses, blinks pause, and the periodic dialogue timer skips a beat.
Everything resumes the moment the desktop is focused again, which is derived
from Hyprland's active toplevel rather than the activewindow event, since
moving to an empty workspace fires no window event at all.

Audio runs through mpv. The talking loop, click blips and the in-game radio
are live, while room ambience is wired but switched off at the master flag in
Sfx.qml. It worked, it just competed with whatever you were doing. The flag is
ambientEnabled, the talking loop is speechEnabled by way of the master switch,
and the wallpaper-driven ambience fade used an mpv IPC socket with a stepped
volume ramp before it was retired.

The window frame experiment is worth mentioning even though it was removed.
It drew the game's hand-drawn PNG frame around every window through an
overlay, tracked by hyprctl geometry polling. It worked on the first window
and fell apart on the rest, since opacity and offsets drifted per window, so
the shell now leans on Hyprland's native milk-red borders instead.

Data flows one way. Tools rip and compile, the shell only reads compiled JS.
dialogue.py walks the Ren'Py scripts with their translations and emits ordered
lines per room. gen_manifests.py inventories sprites, the radio and the
wallpaper pool. gen_bindings.py parses the workspace rules. gen_manifests also
slices gui/frame.png into the corner and edge pieces every outlined surface in
the shell uses, which is the same frame art the game draws around its text.

The cursor tracking uses one persistent python client on the Hyprland IPC
socket, borrowed from the Synoptik shell, polled at ten hertz and smoothed
with Behavior animations. Everything else in the shell avoids timers where a
Behavior will do, since timers wake the render thread for no reason.
