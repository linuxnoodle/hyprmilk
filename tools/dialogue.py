#!/usr/bin/env python3
"""hyprmilk dialogue pipeline.

Parses Ren'Py scripts from the extracted game and emits JSON databases
consumed by the quickshell shell:

  data/dialogue.json  -- ordered dialogue lines per room, with sprite + sfx cues
  data/rooms.json     -- workspace -> room mapping (rooms, plates, ambients)

Sources:
  RU room scripts  (work_dir/*.rpy)        -- authoritative cue order (show/play)
  tl/english/*.rpy                         -- RU->EN translation pairs

Speaker conventions in game:
  gg"..."        girl (script.rpy, bedroom hub)
  z/l/m/t/k"..." room-local narrator (zerk/lest/magaz/telef/kompol)
  "..."          narrator
Sprite cues: show/hide gg_{emotion}_{variant}[_ad|_oa]  (ad=arms_down, oa=one_arm)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/pmkm2-extract")
ASSETS = ROOT / "assets"

ROOMS = {
    # room id -> (script file, {speaker vars})
    "zerk": ("zerk.rpy", {"z"}),
    "lest": ("lest.rpy", {"nl"}),
    "magaz": ("magaz.rpy", {"ggm", "mm", "nm", "trm"}),
    "telef": ("telef.rpy", {"tel", "piz"}),
    "kompol": ("kompol.rpy", {"k"}),
    "hub": ("script.rpy", {"gg", "nvl"}),
}

# sprite token -> (pose, emotion, variant)
SPRITE_RE = re.compile(r"gg_([a-z]+)_(\d+)(_(ad|oa))?\b")
POSE_SUFFIX = {"ad": "arms_down", "oa": "one_arm", None: "arms_crossed"}
EMOTIONS = {"neutral", "smile", "sad", "mad", "conf", "nerv", "zout"}

DIALOGUE_RE = re.compile(
    r'^\s*(?:(?P<spk>[a-z]{1,4})|"|nvl )'
    r'(?P<q>")(?P<text>(?:[^"\\]|\\.)*)"'
)
SHOW_RE = re.compile(r"^\s*(?:show|hide)\s+(gg_\w+)")
PLAY_RE = re.compile(r'^\s*play\s+(music|sound)\s+"?([^"\s]+)"?')
NICE_RE = re.compile(r"nice_sounds")

SCRIPT_LINE_RE = re.compile(r'^\s*(?:(?P<spk>[a-z]{1,4})?\s*)(?P<q>")(?P<text>(?:[^"\\]|\\.)*)"')
# statements that contain quoted strings but are not dialogue
STMT_RE = re.compile(r"^\s*(?:\$|image\s|define\s|default\s|label\s|jump\s|call\s|scene\s|menu|if\s|elif\s|else|translate\s|init|window|pause|hide\s|show\s|play\s|stop\s|queue\s|voice\s|python|expression|return|pass|while\s|old\s|new\s|#)")


def unesc(s: str) -> str:
    return s.replace('\\"', '"').replace("\\\\", "\\")


def parse_ru_script(path: Path, speakers: set[str]):
    """Walk a RU script, collecting dialogue lines with the most recent
    sprite / music / sfx cues attached."""
    lines_out = []
    sprite = None
    music = None
    sfx = None
    in_label = None
    for raw in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        line = raw.rstrip("\r")
        lm = re.match(r"^label\s+(\w+):", line)
        if lm:
            in_label = lm.group(1)
            continue
        sm = SHOW_RE.search(line)
        if sm:
            tok = sm.group(1)
            m = SPRITE_RE.search(tok)
            if m:
                emotion, variant, suffix = m.group(1), int(m.group(2)), m.group(4)
                if emotion in EMOTIONS:
                    sprite = {
                        "pose": POSE_SUFFIX[suffix],
                        "emotion": emotion,
                        "variant": variant,
                    }
            continue
        pm = PLAY_RE.match(line)
        if pm:
            kind, target = pm.group(1), pm.group(2)
            if kind == "music":
                music = target
            elif not NICE_RE.search(target):
                sfx = target
            continue
        # dialogue: speaker"text" OR bare "text" (skip statements)
        if STMT_RE.match(line):
            continue
        dm = SCRIPT_LINE_RE.match(line)
        if dm and dm.group("text").strip():
            spk = dm.group("spk")
            if spk is None or spk in speakers:
                lines_out.append(
                    {
                        "speaker": spk or "narr",
                        "text": unesc(dm.group("text")).strip(),
                        "sprite": dict(sprite) if sprite else None,
                        "music": music,
                        "sfx": sfx,
                    }
                )
    return lines_out


def load_translations(work: Path) -> dict[str, str]:
    """RU text -> EN text from tl/english/*.rpy `# orig` comment + active line."""
    trans = {}
    tl_dir = work / "tl" / "english"
    if not tl_dir.is_dir():
        return trans
    pair = re.compile(
        r'#\s*[a-z]{0,4}\s*"((?:[^"\\]|\\.)*)"\s*$'
    )
    active = re.compile(r'^\s*(?:[a-z]{1,4})?\s*"((?:[^"\\]|\\.)*)"')
    for f in tl_dir.glob("*.rpy"):
        orig = None
        for raw in f.read_text(encoding="utf-8-sig", errors="replace").splitlines():
            cm = pair.search(raw)
            if cm and raw.lstrip().startswith("#"):
                orig = unesc(cm.group(1))
                continue
            am = active.match(raw)
            if am and orig is not None and raw.lstrip() and not raw.lstrip().startswith("#"):
                en = unesc(am.group(1)).strip()
                if en and orig:
                    trans.setdefault(orig, en)
                orig = None
    return trans


def extract_hub(script_lines):
    """Bedroom hub: keep only the `room` label section (post-walk dialogue)."""
    out, inside = [], False
    for ln in script_lines:
        # label boundaries are lost after parse_ru_script; approximate by
        # first girl line after milk5 ambient starts. Simpler: keep all gg lines.
        if ln["speaker"] == "gg":
            out.append(ln)
    return out


def emit_js(name: str, obj):
    (ROOT / "data" / f"{name}.js").write_text(
        f"var {name} = " + json.dumps(obj, ensure_ascii=False) + ";\n",
        encoding="utf-8",
    )


def main():
    trans = load_translations(WORK)
    print(f">> {len(trans)} EN translation pairs")

    dialogue = {}
    for room, (fname, speakers) in ROOMS.items():
        path = WORK / fname
        if not path.exists():
            print(f"!! missing {fname}", file=sys.stderr)
            continue
        lines = parse_ru_script(path, speakers)
        if room == "hub":
            lines = extract_hub(lines)
        # translate
        translated = 0
        for ln in lines:
            en = trans.get(ln["text"])
            if en:
                ln["text"], translated = en, translated + 1
        dialogue[room] = lines
        print(f">> {room:6s}: {len(lines):3d} lines ({translated} translated)")

    emit_js("dialogue", dialogue)

    # ---------------- rooms.json ----------------
    rooms = {}
    ws_map = {1: "hub", 2: "zerk", 3: "lest", 4: "magaz", 5: "telef", 6: "kompol", 7: "ost"}
    for ws, room in ws_map.items():
        if room == "ost":
            rooms[str(ws)] = {
                "id": "ost",
                "name": "dream",
                "plates": ["cg_dream"],
                "ambient": None,
                "radio": True,
            }
            continue
        plate_dir = ASSETS / "rooms" / room
        junk = {"curs", "transmask", "nm"}
        plates = sorted(
            (p.stem for p in plate_dir.glob("*.png") if p.stem not in junk),
            key=lambda s: (len(s), s),
        ) if plate_dir.is_dir() else []
        if room == "hub":
            plates = ["bg"]
        amb = ASSETS / "audio" / "rooms" / room
        ambient = None
        if amb.is_dir():
            tracks = sorted(amb.glob("*.mp3")) or sorted(amb.glob("*.ogg"))
            if room == "hub":
                # milk5 is the bedroom loop (fadein 5 in game)
                pick = [t for t in tracks if t.stem == "milk5"] or tracks
                ambient = "rooms/hub/" + pick[0].name
            elif tracks:
                same = [t for t in tracks if t.stem.startswith(room)]
                pick = same or tracks
                ambient = "rooms/" + room + "/" + pick[0].name
        rooms[str(ws)] = {
            "id": room,
            "plates": plates,
            "ambient": ambient,
        }
    emit_js("rooms", rooms)
    print(">> wrote data/*.js modules")


if __name__ == "__main__":
    main()
