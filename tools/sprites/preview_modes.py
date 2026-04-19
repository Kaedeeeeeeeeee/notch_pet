#!/usr/bin/env python3
"""
Multi-mode preview: all 10 species across key gameplay modes so each
animation silhouette can be eyeballed quickly.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
SHEET = REPO / "NotchPet/Assets/Sprites/pet.png"
META  = REPO / "NotchPet/Assets/Sprites/pet.json"
OUT   = REPO / "tools/sprites/preview_modes.png"

SPECIES = [
    "chick", "cat", "dog", "bird",
    "frog", "snake", "turtle", "snail", "octopus", "slime",
]
# Each column is (label, tag_suffix, frame_offset_within_tag)
COLS = [
    ("idle 0",     "cheerful_adult_idle",      0),
    ("idle 3",     "cheerful_adult_idle",      3),
    ("walk 1",     "cheerful_adult_walk",      1),
    ("happy",      "cheerful_adult_happy",     0),
    ("eat",        "cheerful_adult_eat",       1),
    ("play",       "cheerful_adult_play_act",  1),
    ("bounce",     "cheerful_adult_bounce",    1),
    ("sick",       "cheerful_adult_sick",      0),
    ("sleep",      "cheerful_adult_sleeping",  1),
    ("held",       "cheerful_adult_held",      0),
]

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

for i, (lbl, _, _) in enumerate(COLS):
    draw.text(
        (LABEL_W + i * (cell_px + PAD) + PAD, 6),
        lbl, fill=(60, 50, 30), font=font_small,
    )

for row, sp in enumerate(SPECIES):
    y0 = 30 + row * (cell_px + PAD)
    draw.text((PAD, y0 + cell_px // 2 - 6), sp, fill=(60, 50, 30), font=font)

    for i, (_, suffix, offset) in enumerate(COLS):
        tag_name = f"{sp}_{suffix}"
        tag = tag_by_name.get(tag_name)
        if not tag:
            continue
        idx = tag["from"] + min(offset, tag["to"] - tag["from"])
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
