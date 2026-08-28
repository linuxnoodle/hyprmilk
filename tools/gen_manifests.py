#!/usr/bin/env python3
"""Generate data manifests for the QML shell (QML cannot readdir).

  data/skybox.json  {"skybox": [21,22,...], "mirror": [...]}
  data/sprites.json {"arms_down": {"neutral": {"bodies":[1,2,4], "eyes":{"1":["open","half"],...}, "mouths":["closed","half","full"]}, ...}}
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets"


def skybox():
    idx = sorted(int(p.stem) for p in (A / "bg/skybox").glob("*.png"))
    mir = sorted(int(p.stem) for p in (A / "bg/mirror").glob("*.png"))
    both = sorted(set(idx) & set(mir))
    return {"all": both, "default_range": [i for i in both if 21 <= i <= 60]}


def sprites():
    out = {}
    for pose_dir in sorted((A / "sprites").iterdir()):
        if not pose_dir.is_dir():
            continue
        pose = pose_dir.name
        out[pose] = {}
        for emo_dir in sorted(pose_dir.iterdir()):
            if not emo_dir.is_dir():
                continue
            emo = emo_dir.name
            bodies, eyes, mouths = [], {}, []
            for f in sorted(emo_dir.glob("*.png")):
                s = f.stem
                if re.fullmatch(rf"{emo}_\d+", s):
                    bodies.append(int(s.rsplit("_", 1)[1]))
                elif m := re.fullmatch(rf"{emo}_(\d+)_eyes_(open|half|closed)", s):
                    eyes.setdefault(int(m.group(1)), []).append(m.group(2))
                elif s == f"{emo}_eyes_closed":
                    eyes.setdefault(0, []).append("closed")
                elif m := re.fullmatch(rf"{emo}_mouth_(closed|half|full)", s):
                    mouths.append(m.group(1))
            if bodies or eyes:
                out[pose][emo] = {"bodies": bodies, "eyes": eyes, "mouths": mouths}
    return out


def main():
    data = {
        "skybox": skybox(),
        "sprites": sprites(),
    }
    (ROOT / "data/manifest.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    n_emotions = sum(len(v) for v in data["sprites"].values())
    print(
        f">> manifest: {len(data['skybox']['all'])} skybox pairs, "
        f"{len(data['sprites'])} poses, {n_emotions} pose-emotion combos"
    )


if __name__ == "__main__":
    main()
