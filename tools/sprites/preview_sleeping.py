#!/usr/bin/env python3
"""
Quick preview of the lying-down sleeping poses. Reads the packed sprite
sheet + JSON, pulls every `<species>_cheerful_adult_sleeping` tag's three
frames, scales them 8x for visibility, and writes a labeled grid to
tools/sprites/preview_sleeping.png.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
SHEET = REPO / "NotchPet/Assets/Sprites/pet.png"
META  = REPO / "NotchPet/Assets/Sprites/pet.json"
OUT   = REPO / "tools/sprites/preview_sleeping.png"

SPECIES = ["chick", "cat", "dog", "bird"]
SCALE = 8
PAD = 12
LABEL_W = 80

with open(META) as f:
    data = json.load(f)

frames = data["frames"]  # list of {filename, frame:{x,y,w,h}, ...}
tags = data["meta"]["frameTags"]  # [{name, from, to}]

tag_by_name = {t["name"]: t for t in tags}
sheet = Image.open(SHEET).convert("RGBA")

# Cell size (16x16 by design)
CELL = 16

cols = 3  # 3 frames per species
rows = len(SPECIES)

cell_px = CELL * SCALE
grid_w = LABEL_W + cols * (cell_px + PAD) + PAD
grid_h = PAD + rows * (cell_px + PAD) + 30  # top header

canvas = Image.new("RGBA", (grid_w, grid_h), (245, 238, 220, 255))
draw = ImageDraw.Draw(canvas)

try:
    font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 14)
    font_small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 11)
except Exception:
    font = ImageFont.load_default()
    font_small = font

# Header
for i in range(cols):
    draw.text((LABEL_W + i * (cell_px + PAD) + PAD, 6),
              f"frame {i}", fill=(60, 50, 30), font=font_small)

for row, sp in enumerate(SPECIES):
    tag_name = f"{sp}_cheerful_adult_sleeping"
    tag = tag_by_name.get(tag_name)
    if not tag:
        print(f"missing tag: {tag_name}")
        continue

    y0 = 30 + row * (cell_px + PAD)
    draw.text((PAD, y0 + cell_px // 2 - 8), sp, fill=(60, 50, 30), font=font)

    for i, idx in enumerate(range(tag["from"], tag["to"] + 1)):
        entry = frames[idx]
        r = entry["frame"]
        sub = sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        sub = sub.resize((r["w"] * SCALE, r["h"] * SCALE), Image.NEAREST)
        x = LABEL_W + i * (cell_px + PAD) + PAD
        # Checker background so transparency reads cleanly
        bg = Image.new("RGBA", (cell_px, cell_px), (220, 210, 190, 255))
        canvas.paste(bg, (x, y0))
        canvas.paste(sub, (x, y0), sub)

canvas.save(OUT)
print(f"wrote {OUT}  ({grid_w}x{grid_h})")
