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

# lua numeric for-loop wrapping workspace rules:
#   for i = 1, 10 do hl.workspace_rule({ workspace = tostring(i), ... }) end
LOOP = re.compile(
    r'for\s+(?P<var>\w+)\s*=\s*(?P<lo>\d+)\s*,\s*(?P<hi>\d+)\s+do(?P<body>.*?)\nend',
    re.S,
)
MON = re.compile(r"monitor\s*=\s*['\"]([A-Za-z0-9_-]+)['\"]")
WS = re.compile(r"workspace\s*=\s*['\"](\d+)['\"]")


def _collect(body: str, var: str | None, lo: int, hi: int, bind: dict) -> None:
    """Scan lua source for workspace_rule blocks; expand loop vars."""
    for m in RULE.finditer(body):
        b = m.group("body")
        mon = MON.search(b)
        if not mon:
            continue
        if var and re.search(rf'workspace\s*=\s*tostring\(\s*{re.escape(var)}\s*\)', b):
            bind.setdefault(mon.group(1), set()).update(range(lo, hi + 1))
            continue
        ws = WS.search(b)
        if ws:
            bind.setdefault(mon.group(1), set()).add(int(ws.group(1)))


def parse() -> dict:
    bind: dict[str, set] = {}
    if not LUA.exists():
        return bind
    text = LUA.read_text(errors="replace")
    # strip comments first — commented-out rules must not inject entries
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)

    loop_spans = []
    for m in LOOP.finditer(text):
        _collect(m.group("body"), m.group("var"),
                 int(m.group("lo")), int(m.group("hi")), bind)
        loop_spans.append(m.span())

    def in_loop(pos: int) -> bool:
        return any(s <= pos < e for s, e in loop_spans)

    for m in RULE.finditer(text):
        if in_loop(m.start()):
            continue   # already handled by loop expansion
        # NOTE: pass the FULL match — _collect re-runs RULE on it, and
        # m.group("body") is only the {..} interior (no rule prefix)
        _collect(m.group(0), None, 0, 0, bind)

    return {k: sorted(v) for k, v in bind.items()}


def main():
    bind = parse()
    (ROOT / "data/wsbindings.js").write_text(
        f"var wsbindings = " + json.dumps(bind) + ";\n", encoding="utf-8"
    )
    if not bind:
        print(">> wsbindings: {} (no workspace rules matched — bar falls back to "
              "per-monitor live list; check hl.workspace_rule syntax)")
    else:
        print(">> wsbindings:", bind)


if __name__ == "__main__":
    main()