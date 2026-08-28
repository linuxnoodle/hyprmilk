# hyprmilk — Implementation Plan

Recreate the "Milk Outside A Bag Of Milk" Hyprland rice (r/hyprland 1u8f4qq):
Quickshell desktop shell themed on *Milk outside a bag of milk outside a bag of milk*
(Ren'Py VN, assets ripped from Steam install).

References studied:
- `EC2854/dotfiles` (main branch) — quickshell milk rice, assets stripped by author.
  Gave us: QML module layout, bar geometry, palette, Bg.qml layering
  (room + skybox 21–60 + mirror), workspace widget colors, Walker launcher.
- `Kiaryy/Milk-Outside-a-Bag-of-Milk-GTK-Theme` — palette confirmation
  (accent `#ac3232`, greys).
- Game extracted to `/tmp/pmkm2-extract` (1250 files, 678 MB) — full asset inventory below.

---

## 1. Palette & Theme Tokens

Single source of truth: `Theme.qml` singleton (quickshell `Singleton`).

| Token | Value | Source |
|---|---|---|
| `accent` | `#ac3232` | GTK theme DecorationFocus (172,50,50); EC2854 bar uses `#ac3231` |
| `bg` | `#0d0d14` | EC2854 bar panels |
| `bg2` | `#31363b` | GTK BackgroundNormal (49,54,59) |
| `bg3` | `#3b4045` | GTK BackgroundAlternate (59,64,69) |
| `fg` | `#ffffff` | |
| `fg2` | `#c4c4c4` | game dialogue text color (`what_color='#c4c4c4'`) |
| `wsExists` | `#52263e` | EC2854 workspace dot |
| `wsActive` | `#ac3231` | EC2854 workspace dot |
| `border` | 2px `#3b4045`, PNG 9-slice style | EC2854 `widgets/Border.qml` + `assets/border/*.png` |

Fonts: game's own `images/122.ttf`, `images/aaa.ttf` + a pixel terminal font
(EC2854 used BigBlueTerminal Nerd Font). Terminal = kitty, shell = fish (reddit rice stack).

Pixel-art rule: all game-derived imagery rendered `smooth: false`, no fractional scaling.

---

## 2. Asset Pipeline (from extracted game)

Extraction done: `unrpa` venv, RPA-3.0, → `/tmp/pmkm2-extract`.
Keep a `tools/extract.sh` that re-does this (unrpa + cp subset) so repo stays
small; curated assets committed under `assets/`.

### Curated asset tree (target)

```
assets/
  bg/
    bg.png                      # base room plate (game: images/bg.png)
    skybox/{1..85}.png          # 1920x1080, 3.6 MB — cloud/sky variants
    mirror/{N}.png              # per-skybox mirror-lake overlay (EC2854 paired 21–60)
  rooms/
    zerk/{1..11}.png            # mirror room   (RU: зеркало)
    lest/{1..16}.png            # stairs        (RU: лестница)
    magaz/{1..18}.png           # shop          (RU: магазин)
    telef/{1..10}.png           # phone         (RU: телефон)
    kompol/{1..18}.png          # hall/corridor
    room/{...}.png              # bedroom hub scene (from script.rpy `room` label)
    balcony/ fall/ dream/ firefly/ pills/ ceiling/ floor/   # CG extras, later
  sprites/
    arms_down|arms_crossed|one_arm/
      neutral|smile|sad|mad|conf|nerv|zout/
        {N}.png  {N}_eyes_{open,half}.png  eyes_closed.png
        mouth_{closed,half,full}.png
  gui/
    frame.png  bar/{top,bottom,left,right}.png  button/  slider/  overlay/
  audio/
    rooms/{zerk,lest,magaz,telef,kompol}/*.mp3   # ambient loops per room
    voice/milk{1..45}.mp3                        # 39 files present
    radio/radio{1,2,3}/*.mp3                     # 3 stations, 12–15 tracks each
    ui/{1..7}.ogg Button1.mp3 Button2.mp3 narr.ogg clock.ogg
  fonts/122.ttf fonts/aaa.ttf
```

### Sprite rig (decoded from `sprites arms_down.rpy`)

LiveComposite 1959×1027, three layers:

- **body**: variant `{N}.png` (1–4 per pose/emotion)
- **eyes**: `{N}_eyes_open` → hold random 2–6 s → `_eyes_half` (0.1 s) →
  `eyes_closed` (0.2 s) → `_eyes_half` (0.1 s) → repeat
- **mouth**: while dialogue "speaking": `mouth_half` (0.1 s) ⇄ `mouth_full`
  (0.1 s) loop; idle → `mouth_closed`

Poses: `arms_down`, `arms_crossed`, `one_arm`.
Emotions: `neutral`, `smile`, `sad`, `mad`, `conf`, `nerv`, `zout`.

QML implementation: one `MilkChan.qml` — `Image` stack + `Timer`s replicating
the above timing exactly (blink timer w/ randomized interval, talk flap timer
gated by a `speaking` property).

### Dialogue DB

Parser `tools/dialogue.py`: read `tl/english/*.rpy` (EN; game source is RU),
strip Ren'Py syntax, emit `data/dialogue.json`:

```json
{
  "room":  [{"who": "gg", "text": "...", "voice": "milk7"},
            {"who": null, "text": "..."}],
  "zerk":  [...], "lest": [...], "magaz": [...], "telef": [...], "kompol": [...]
}
```

~326 EN lines total in tl/english/script.rpy + per-room scripts.
Voice line mapping: game plays `audio/milk/N.mp3` in lockstep with dialogue
(missing indices 22/24/26–30 → those lines have no voice).

---

## 3. Quickshell Architecture

Mirrors EC2854 layout (proven structure):

```
~/.config/quickshell/
  shell.qml                 # ShellRoot: bg, bar, osd, notifs, lock, launcher, dialogue
  Theme.qml                 # singleton tokens
  bg/       Bg.qml, Room.qml, MilkChan.qml
  bar/      Bar.qml, Workspaces.qml, Volume.qml, Power.qml
  widgets/  Border.qml, Time.qml, SpriteAnim.qml
  launcher/ Launcher.qml    # app launcher (fuzzy, PNG-bordered)
  music/    Player.qml      # MPRIS + game-music mode
  notifs/   Notif.qml, Display.qml, Center.qml   # toasts + notification center
  osd/      Osd.qml         # volume popup
  dialogue/ Box.qml, Engine.js  # VN textbox + typewriter engine
  data/     dialogue.json, rooms.json
  assets/   (curated tree above)
```

### 3.1 Background / Skybox engine — `bg/Bg.qml`

PanelWindow fullscreen, `exclusionMode: ExclusionMode.Ignore`, below windows.
Layer stack (EC2854 exact):

1. `rooms/{room}.png` — current room plate (workspace-driven, §3.4)
2. skybox image — `skybox/{index}.png`, `PreserveAspectCrop`, `smooth:false`
3. `mirror/{index}.png` overlay — same index

`index` random 21–60 on start (as EC2854). Skybox switcher: button in bar /
launcher action → re-roll (animated crossfade 250 ms). Full set is 85 — expose
all, default range 21–60.

### 3.2 Milk-Chan — `bg/MilkChan.qml`

Sprite per §2 rig, anchored bottom-center of screen (or side), behind bar,
above bg. Behavior:

- On room/workspace change: pick random pose + emotion + body variant
- Idle blink loop always running
- `speaking` true while dialogue typewriter active → mouth flap
- Optional: emotion reacts to events (battery low → `sad`, volume max → `mad`,
  notification → `conf`…) — same random-reseed mechanism
- Clickable → cycles pose; tooltip = current emotion (cheap fun, matches
  "randomly changes poses and emotions" of original)

### 3.3 Bar — `bar/Bar.qml`

EC2854 geometry: top, exclusiveZone 42, floating 28 px row, 8 px margins,
segments with `Border` 9-slice + `#0d0d14`:

- **left**: Workspaces — 7×24 px pixel circles (`workspace-button.png` overlay,
  colors: active `#ac3231`, exists `#52263e`, empty `#0d0d14`), wheel + click nav
- **center**: music segment (appears only when track playing, animated width)
- **right**: tray — Volume, Mic(voice-mute), Power + clock segment (hover → date)
- Room name label segment (current workspace's room) — small, `fg2`

### 3.4 Rooms per workspace — `bg/Room.qml` + `data/rooms.json`

Workspace→room map (reddit feature "rooms and dialogue change per workspace"):

| WS | Room | Ambient |
|---|---|---|
| 1 | `room` (bedroom hub) | `audio/…` room hum + clock.ogg tick |
| 2 | `zerk` (mirror) | `audio/zerk/zerk1.mp3` |
| 3 | `lest` (stairs) | `audio/lest/lest1.mp3` |
| 4 | `magaz` (shop) | `audio/magaz/magaz1.mp3` |
| 5 | `telef` (phone) | `audio/telef/…` |
| 6 | `kompol` (hall) | `audio/kompol/…` |
| 7 | balcony/fall/dream CG rotation | game OST |

Implementation: `Quickshell.Hyprland` `Hyprland.monitor.activeWorkspace` binding →
room id → swap room plate (crossfade), start room ambient in mpv instance #1,
fire one dialogue line-set for that room (§3.5).

### 3.5 Dialogue box — `dialogue/Box.qml`

Bottom-center textbox, game GUI kit (`gui/frame.png` + `gui/bar/*` edges as
9-slice), text `#c4c4c4`, game font. Engine:

- Typewriter reveal (~25 cps), `speaking` property drives sprite mouth
- Queue per room from `dialogue.json`; on workspace enter show 1–3 random lines
- Click / keybind → advance; idle → auto-hide after N s
- Voice: play matching `voice/milkN.mp3` via mpv instance #2 (piped volume);
  global mute toggle (bar Mic button doubles as "Milk-Chan voice mute" — reddit
  calls this out explicitly; store state in `~/.local/state/hyprmilk/voice`)

### 3.6 Music player — `music/Player.qml`

Two sources (reddit: "device music or game music"):
- **MPRIS** via `Quickshell.Services.Mpris` — Spotify/browser/etc, playerctl
  fallback for control commands
- **Game mode** — mpv shuffle of `audio/radio/radio{1,2,3}/*` (3 stations) +
  OST; station selector in player popup

Popup (click bar center segment): cover/name/pos, prev/play/next, station
picker, progress bar skinned with `gui/slider/*` PNGs.

### 3.7 Launcher — `launcher/Launcher.qml`

QML popup (or Walker if we want zero effort — EC2854 pairs it): fuzzy app
search, PNG border, `#0d0d14` bg, red selection, `Button1.mp3` on activate,
`milk_hover.ogg` on item hover. Extra entries: "Switch skybox", "Next room",
"Radio station…".

### 3.8 Notifications — `notifs/`

- Toast: top-right, Border 9-slice, red accent bar, game UI sfx
- Center: click tray / keybind → panel listing history (workspace-aware flavor
  text: room narrator comments as section headers)

### 3.9 OSD — `osd/Osd.qml`

Volume popup: small framed box, pixel slider (`gui/slider/*`), auto-hide 1.5 s.
Wire to `pactl`/wireplumber via Quickshell audio service. `no.ogg` on mute.

### 3.10 Lock — `lock/`

EC2854-style PAM lock: bg = current room + skybox blurred… actually game-faithful:
dark overlay + Milk-Chan `nerv` sprite + "…" dialogue line. Reuses PAM helper.

---

## 4. Hyprland / system integration

- `hypr/*.conf`: exec-once `qs -c hyprmilk`, keybinds (launcher, notif center,
  skybox re-roll, dialogue advance, voice mute), windowrules (float walker etc),
  gaps 8, border `#3b4045` 2px, active border `#ac3232`
- mpv instances managed by shell via `Quickshell.Io.Process`: `--no-video
  --loop-file=inf` for ambients; `--af=scaletempo` n/a for voice
- kitty config: palette from tokens, game font for prompt
- fish: prompt `milk> `, bobthefish stripped, palette
- Firefox + Spicetify: port GTK theme colors (`userChrome.css` /
  color.ini) — separate dirs `firefox/`, `spicetify/`
- Optional: cursor theme from game `images/curs.png` (xcursor-build)

---

## 5. Milestones

1. **M1 — assets**: `tools/extract.sh` (unrpa → curate → `assets/`),
   `tools/dialogue.py` → `data/dialogue.json`, verify sprite sets complete
2. **M2 — shell skeleton**: Theme, shell.qml, Bg (3-layer + skybox re-roll),
   bar (workspaces/clock/tray), Border/Time widgets — parity with EC2854
3. **M3 — Milk-Chan**: sprite rig + blink/talk timers, pose/emotion reseed
4. **M4 — rooms**: workspace→room map, plate swap, ambient mpv, dialogue box +
   voice; voice-mute toggle
5. **M5 — player + launcher + notif center + OSD**
6. **M6 — kitty/fish/firefox/spicetify/cursors + README**

## 6. Open questions / risks

- `assets/bg/mirror/N.png` in EC2854 came from `images/cg_mirror/cg_mirror_gg`
  (85 frames) — confirm pairing skybox↔mirror indices before wiring randomizer
- Voice↔text mapping: derive by order (milkN ↔ Nth voiced line) while parsing
  .rpy `play voice` adjacency in RU source; spot-check a few by ear
- 909 PNGs @ full res ≈ heavy; webp-convert non-critical CGs, keep sprite/skybox
  PNG (palette, crisp pixels)
- Reddit rice ran on NixOS too — keep shell self-contained (no ABS paths beyond
  `~/.config/quickshell`) so a Nix flake can wrap it later
