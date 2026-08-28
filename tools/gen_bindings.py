#!/usr/bin/env python3
"""Parse ~/.config/hypr/hyprland.lua workspace_rules -> data/wsbindings.js.

Gives the shell static per-monitor workspace IDs (so e.g. DP-2 always shows
6-10 even before empty workspaces are first visited).
Fallback: if the lua is missing/unparsable, emit {} and the shell falls back
to `hyprctl workspaces -j` dynamically.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = Path.home() / ".config/hypr/hyprland.lua"

RULE = re.compile(
    r'hl\.workspace_rule\(\s*\{(?P<body>.*?)\}\s*\)',
    re.S,
)


def parse() -> dict:
    bind = {}
    if not LUA.exists():
        return bind
    for m in RULE.finditer(LUA.read_text(errors="replace")):
        body = m.group("body")
        ws = re.search(r'workspace\s*=\s*"(\d+)"', body)
        mon = re.search(r'monitor\s*=\s*"([A-Za-z0-9_-]+)"', body)
        if ws and mon:
            bind.setdefault(mon.group(1), set()).add(int(ws.group(1)))
    return {k: sorted(v) for k, v in bind.items()}


def main():
    bind = parse()
    (ROOT / "data/wsbindings.js").write_text(
        f"var wsbindings = " + json.dumps(bind) + ";\n", encoding="utf-8"
    )
    print(">> wsbindings:", bind)


if __name__ == "__main__":
    main()