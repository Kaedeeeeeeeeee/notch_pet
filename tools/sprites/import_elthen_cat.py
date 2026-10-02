#!/usr/bin/env python3
"""Import Elthen's 32x32 cat sheet into NotchPet's Aseprite JSON shape.

Source asset:
https://elthen.itch.io/2d-pixel-art-cat-sprites
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "tools/sprites/vendor/elthen_cat/CatSpriteSheet.png"
OUT_PNG = REPO / "NotchPet/Assets/Sprites/pet.png"
OUT_JSON = REPO / "NotchPet/Assets/Sprites/pet.json"

SOURCE_FRAME = 32
FRAME_W = 32
# Extra headroom for jump / play frames. The source art remains 32px wide and
# is pasted at the bottom so feet stay on the same baseline.
FRAME_H = 40
SOURCE_Y = FRAME_H - SOURCE_FRAME
COLS = 8
ROWS = 10

# The Swift fallback chain maps every species/personality to these shared
# tags. Keeping a single exported variant avoids thousands of duplicate frames
# while we evaluate the new art direction.
SPECIES = ["chick"]
PERSONALITIES = ["cheerful"]

CHILD_MODES = [
    "idle",
    "hungry",
    "happy",
    "sick",
    "sleeping",
    "curious",
    "angry",
    "walk",
    "peck",
    "flap",
    "dance",
    "stretch",
    "sit",
    "eat",
    "play_act",
    "medic",
    "poop_act",
    "clean_act",
    "held",
]

ADULT_MODES = CHILD_MODES + [
    "bounce",
    "hide",
    "lookaway",
    "lick",
    "yawn",
    "huff",
]


MODE_ROWS = {
    "idle": [(0, 0), (0, 1), (0, 2), (0, 3)],
    "happy": [(1, 0), (1, 1), (1, 2), (1, 3)],
    "hungry": [(9, 0), (9, 1), (9, 2), (9, 3)],
    "sick": [(9, 4), (9, 5), (9, 6), (9, 7)],
    "sleeping": [(6, 0), (6, 1), (6, 2), (6, 3)],
    "curious": [(7, 0), (7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    "angry": [(9, 0), (9, 1), (9, 2), (9, 3)],
    "walk": [(4, c) for c in range(8)],
    "peck": [(7, 0), (7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    "flap": [(8, 0), (8, 1), (8, 2), (8, 3)],
    "dance": [(4, c) for c in range(8)],
    "stretch": [(8, 0), (8, 1), (8, 2), (8, 3)],
    "sit": [(0, 0), (0, 1), (0, 2), (0, 3)],
    "eat": [(5, c) for c in range(8)],
    "play_act": [(8, 0), (8, 1), (8, 2), (8, 3), (8, 4), (8, 5), (8, 6)],
    "medic": [(7, 0), (7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    "poop_act": [(5, c) for c in range(8)],
    "clean_act": [(2, 0), (2, 1), (2, 2), (2, 3), (3, 0), (3, 1), (3, 2), (3, 3)],
    "held": [(0, 0), (0, 1), (0, 2), (0, 3)],
    "bounce": [(8, 0), (8, 1), (8, 2), (8, 3)],
    "hide": [(9, 4), (9, 5), (9, 6), (9, 7)],
    "lookaway": [(1, 0), (1, 1), (1, 2), (1, 3)],
    "lick": [(5, c) for c in range(8)],
    "yawn": [(6, 0), (6, 1), (6, 2), (6, 3)],
    "huff": [(9, 0), (9, 1), (9, 2), (9, 3)],
}

EGG_FRAMES = [("egg", 0), ("egg", 1), ("egg", 2), ("egg", 1)]


def make_transparent(cell: Image.Image) -> Image.Image:
    """Convert the sheet's white background to alpha."""
    rgba = cell.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if r >= 245 and g >= 245 and b >= 245:
                pixels[x, y] = (255, 255, 255, 0)
    return rgba


def draw_egg(frame_index: int) -> Image.Image:
    img = Image.new("RGBA", (FRAME_W, FRAME_H), (255, 255, 255, 0))
    px = img.load()
    wobble = [0, -1, 0, 1][frame_index % 4]

    outline = (78, 51, 32, 255)
    shadow = (184, 135, 72, 255)
    shell = (255, 239, 196, 255)
    light = (255, 252, 230, 255)
    speckle = (203, 138, 82, 255)

    rows = {
        8: range(13, 19),
        9: range(11, 21),
        10: range(10, 22),
        11: range(9, 23),
        12: range(8, 24),
        13: range(8, 24),
        14: range(7, 25),
        15: range(7, 25),
        16: range(7, 25),
        17: range(8, 24),
        18: range(8, 24),
        19: range(9, 23),
        20: range(10, 22),
        21: range(11, 21),
        22: range(13, 19),
    }
    for y, xs in rows.items():
        yy = y + SOURCE_Y + wobble
        for x in xs:
            left = min(xs)
            right = max(xs)
            if x in (left, right) or y in (8, 22):
                px[x, yy] = outline
            elif x > right - 3 or y > 19:
                px[x, yy] = shadow
            else:
                px[x, yy] = shell

    for x, y in [(12, 10), (13, 10), (11, 11), (12, 11), (10, 12), (11, 12)]:
        px[x, y + SOURCE_Y + wobble] = light
    for x, y in [(17, 13), (19, 15), (14, 17), (16, 19)]:
        px[x, y + SOURCE_Y + wobble] = speckle
    if frame_index == 2:
        for x, y in [(15, 9), (16, 10), (15, 11), (16, 12)]:
            px[x, y + SOURCE_Y] = outline
    return img


def frame_name(index: int) -> str:
    return f"pet {index}.aseprite"


def add_tag(frames, tags, source, name, coords):
    start = len(frames)
    for row, col in coords:
        frames.append((name, row, col))
    tags.append(
        {
            "name": name,
            "from": start,
            "to": len(frames) - 1,
            "direction": "forward",
            "color": "#000000ff",
        }
    )


def build() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source sheet: {SRC}")

    source = Image.open(SRC).convert("RGBA")
    if source.size != (COLS * SOURCE_FRAME, ROWS * SOURCE_FRAME):
        raise SystemExit(f"Expected {COLS * SOURCE_FRAME}x{ROWS * SOURCE_FRAME}, got {source.size}")

    frames = []
    tags = []
    for species in SPECIES:
        add_tag(frames, tags, source, f"{species}_egg_idle", EGG_FRAMES)
        for mode in CHILD_MODES:
            add_tag(frames, tags, source, f"{species}_child_{mode}", MODE_ROWS[mode])
        for personality in PERSONALITIES:
            for stage in ["adult", "elder"]:
                for mode in ADULT_MODES:
                    add_tag(frames, tags, source, f"{species}_{personality}_{stage}_{mode}", MODE_ROWS[mode])
        add_tag(frames, tags, source, f"{species}_departed_idle", MODE_ROWS["sleeping"])

    sheet_cols = 32
    sheet_rows = (len(frames) + sheet_cols - 1) // sheet_cols
    sheet = Image.new("RGBA", (sheet_cols * FRAME_W, sheet_rows * FRAME_H), (255, 255, 255, 0))
    json_frames = []

    for index, (_tag, row, col) in enumerate(frames):
        if row == "egg":
            cell = draw_egg(col)
        else:
            sx = col * SOURCE_FRAME
            sy = row * SOURCE_FRAME
            source_cell = make_transparent(source.crop((sx, sy, sx + SOURCE_FRAME, sy + SOURCE_FRAME)))
            cell = Image.new("RGBA", (FRAME_W, FRAME_H), (255, 255, 255, 0))
            cell.alpha_composite(source_cell, (0, SOURCE_Y))
        dx = (index % sheet_cols) * FRAME_W
        dy = (index // sheet_cols) * FRAME_H
        sheet.alpha_composite(cell, (dx, dy))
        json_frames.append(
            {
                "filename": frame_name(index),
                "frame": {"x": dx, "y": dy, "w": FRAME_W, "h": FRAME_H},
                "rotated": False,
                "trimmed": False,
                "spriteSourceSize": {"x": 0, "y": 0, "w": FRAME_W, "h": FRAME_H},
                "sourceSize": {"w": FRAME_W, "h": FRAME_H},
                "duration": 120,
            }
        )

    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_PNG)
    OUT_JSON.write_text(
        json.dumps(
            {
                "frames": json_frames,
                "meta": {
                    "app": "NotchPet Elthen importer",
                    "version": "1.0",
                    "image": "pet.png",
                    "format": "RGBA8888",
                    "size": {"w": sheet.width, "h": sheet.height},
                    "scale": "1",
                    "frameTags": tags,
                },
            },
            indent=2,
        )
        + "\n"
    )
    print(f"Wrote {OUT_PNG} ({sheet.width}x{sheet.height})")
    print(f"Wrote {OUT_JSON} ({len(json_frames)} frames, {len(tags)} tags)")


if __name__ == "__main__":
    build()
