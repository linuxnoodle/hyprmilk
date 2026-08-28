#!/usr/bin/env python3
"""Slice gui/frame.png into small 9-slice pieces used by widgets/Border.qml.

Trims each piece to its visible ring and scales to fixed small sizes so the
stylized outline fits tiny UI elements (bar segments, OSD, launcher, ...).
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/gui/frame.png"
OUT = ROOT / "assets/gui/frame9"
M = 48           # pre-crop margin to isolate a piece
EDGE_H = 6      # thin outline, closer to the girl's hand-drawn line
CORNER = 12
MIN = 2          # avoid string-bean slices

im = Image.open(SRC).convert("RGBA")
W, H = im.size


def trim_and_scale(piece: Image.Image, target: tuple) -> Image.Image:
    a = piece.getchannel("A")
    box = a.getbbox()
    if box is None:
        return piece.resize(target, Image.LANCZOS)
    piece = piece.crop(box)
    if piece.width < MIN or piece.height < MIN:
        return piece.resize(target, Image.LANCZOS)
    return piece.resize(target, Image.LANCZOS)


def edge(y0, y1, x0, x1, target):
    return trim_and_scale(im.crop((x0, y0, x1, y1)), target)


pieces = {
    "tl": edge(0, M, 0, M, (CORNER, CORNER)),
    "tr": edge(0, M, W - M, W, (CORNER, CORNER)),
    "bl": edge(H - M, H, 0, M, (CORNER, CORNER)),
    "br": edge(H - M, H, W - M, W, (CORNER, CORNER)),
    "t":  edge(0, M, M, W - M, (max(1, (W - 2 * M) * EDGE_H // H), EDGE_H)),
    "b":  edge(H - M, H, M, W - M, (max(1, (W - 2 * M) * EDGE_H // H), EDGE_H)),
    "l":  edge(M, H - M, 0, M, (EDGE_H, max(1, (H - 2 * M) * EDGE_H // W))),
    "r":  edge(M, H - M, W - M, W, (EDGE_H, max(1, (H - 2 * M) * EDGE_H // W))),
}

OUT.mkdir(parents=True, exist_ok=True)
for name, piece in pieces.items():
    piece.save(OUT / f"{name}.png")

print(">> frame9:", {k: v.size for k, v in pieces.items()})