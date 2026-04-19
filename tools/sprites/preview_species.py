#!/usr/bin/env python3
"""
Full-matrix preview: all 10 species × key poses (idle, sleeping, signature
per-personality pose where applicable). Scales 6× for visibility and writes
tools/sprites/preview_species.png.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
SHEET = REPO / "NotchPet/Assets/Sprites/pet.png"
META  = REPO / "NotchPet/Assets/Sprites/pet.json"
OUT   = REPO / "tools/sprites/preview_species.png"

SPECIES = [
    "chick", "cat", "dog", "bird",
    "frog", "snake", "turtle", "snail", "octopus", "slime",
]
PERSONALITIES = ["cheerful", "shy", "aloof", "gluttonous", "lazy", "grumpy"]

# Columns: idle + sleeping + the 6 personalities (idle under each)
COLS = ["cheerful_adult_idle", "cheerful_adult_sleeping"] + [
    f"{p}_adult_idle" for p in PERSONALITIES
]
COL_LABELS = ["idle", "sleep"] + PERSONALITIES

SCALE = 6
CELL = 16
PAD = 6
LABEL_W = 70

with open(META) as f:
    data = json.load(f)

frames = data["frames"]
tags = data["meta"]["frameTags"]
tag_by_name = {t["name"]: t for t in tags}
sheet = Image.open(SHEET).convert("RGBA")

cell_px = CELL * SCALE
grid_w = LABEL_W + len(COLS) * (cell_px + PAD) + PAD
grid_h = 30 + len(SPECIES) * (cell_px + PAD) + PAD

canvas = Image.new("RGBA", (grid_w, grid_h), (245, 238, 220, 255))
draw = ImageDraw.Draw(canvas)

try:
    font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 12)
    font_small = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 10)
except Exception:
    font = ImageFont.load_default()
    font_small = font

# Column headers
for i, lbl in enumerate(COL_LABELS):
    draw.text(
        (LABEL_W + i * (cell_px + PAD) + PAD, 6),
        lbl, fill=(60, 50, 30), font=font_small,
    )

for row, sp in enumerate(SPECIES):
    y0 = 30 + row * (cell_px + PAD)
    draw.text((PAD, y0 + cell_px // 2 - 6), sp, fill=(60, 50, 30), font=font)

    for i, col in enumerate(COLS):
        tag_name = f"{sp}_{col}"
        tag = tag_by_name.get(tag_name)
        if not tag:
            continue
        idx = tag["from"]  # first frame of tag
        entry = frames[idx]
        r = entry["frame"]
        sub = sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        sub = sub.resize((r["w"] * SCALE, r["h"] * SCALE), Image.NEAREST)
        x = LABEL_W + i * (cell_px + PAD) + PAD
        bg = Image.new("RGBA", (cell_px, cell_px), (220, 210, 190, 255))
        canvas.paste(bg, (x, y0))
        canvas.paste(sub, (x, y0), sub)

canvas.save(OUT)
print(f"wrote {OUT}  ({grid_w}x{grid_h})")
