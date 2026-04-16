-- Block 6 furniture spritesheet generator.
--
-- Emits one 16×16 tag per furniture id defined in FurnitureCatalog.swift.
-- Small hand-drawn pixel art shared between the management panel
-- thumbnails and the in-room placement renderer.
--
-- Run via tools/sprites/build_furniture.sh from repo root.

local OUTPUT = "tools/sprites/furniture.aseprite"
local SIDE = 16

local function C(r, g, b, a)
    return Color{ r = r, g = g, b = b, a = a or 255 }
end

local function inBounds(x, y)
    return x >= 0 and x < SIDE and y >= 0 and y < SIDE
end

-- Color palette (re-used across items)
local OUTLINE = C(34, 22, 12)
local WOOD    = C(145, 92, 40)
local WOODHI  = C(200, 130, 60)
local LEAF    = C(45, 160, 60)
local LEAFHI  = C(120, 220, 130)
local POT     = C(170, 75, 45)
local POTHI   = C(220, 120, 80)
local RED     = C(220, 55, 60)
local REDHI   = C(255, 140, 140)
local CUSHION  = C(225, 150, 180)
local CUSHIONHI = C(255, 200, 220)
local LANTERN = C(240, 220, 100)
local LANTHI  = C(255, 250, 190)
local LANTBAND = C(180, 50, 40)
local PAPER   = C(230, 225, 210)
local INK     = C(25, 35, 100)

local function renderGrid(img, grid, palette)
    for row = 1, SIDE do
        for col = 1, SIDE do
            local cell = grid[row][col]
            if cell ~= 0 then
                local color = palette[cell]
                if color then
                    img:drawPixel(col - 1, row - 1, color)
                end
            end
        end
    end
end

------------------------------------------------------------------
-- Furniture grids. Legend per-item is in the item's palette table.
------------------------------------------------------------------

-- ball: a small red bouncy ball with a highlight
local BALL = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0},
    {0,0,0,0,1,2,3,3,2,2,2,1,0,0,0,0},
    {0,0,0,1,2,3,3,2,2,2,2,2,1,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,2,1,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,2,1,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,2,1,0,0,0},
    {0,0,0,0,1,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local BALL_PALETTE = { [1] = OUTLINE, [2] = RED, [3] = REDHI }

-- table: a low wooden table
local TABLE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
    {0,1,2,3,3,3,3,3,3,3,3,3,3,2,1,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0},
    {0,0,1,2,1,0,0,0,0,0,0,1,2,1,0,0},
    {0,0,1,2,1,0,0,0,0,0,0,1,2,1,0,0},
    {0,0,1,2,1,0,0,0,0,0,0,1,2,1,0,0},
    {0,0,1,2,1,0,0,0,0,0,0,1,2,1,0,0},
    {0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local TABLE_PALETTE = { [1] = OUTLINE, [2] = WOOD, [3] = WOODHI }

-- cushion: a soft pink round cushion
local CUSHION_SHAPE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0},
    {0,0,1,2,3,3,2,2,2,2,2,2,2,1,0,0},
    {0,1,2,3,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,0,1,2,2,2,2,2,2,2,2,2,2,1,0,0},
    {0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local CUSHION_PALETTE = { [1] = OUTLINE, [2] = CUSHION, [3] = CUSHIONHI }

-- plant: a small leafy plant in a terracotta pot
local PLANT = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,5,6,5,0,0,5,0,0,0,0,0},
    {0,0,0,0,5,6,6,5,5,5,6,5,0,0,0,0},
    {0,0,0,5,6,6,6,6,5,6,6,5,0,0,0,0},
    {0,0,5,5,6,6,5,6,5,6,5,5,0,0,0,0},
    {0,0,0,5,5,5,5,5,5,5,5,0,0,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,1,0,0,0,0,0},
    {0,0,1,2,2,3,3,3,3,2,2,1,0,0,0,0},
    {0,0,1,2,2,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,1,2,2,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,1,0,0,0,0,0},
    {0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local PLANT_PALETTE = { [1] = OUTLINE, [2] = POT, [3] = POTHI, [5] = LEAF, [6] = LEAFHI }

-- lantern: a paper lantern on a cord (wall item)
local LANTERN_SHAPE = {
    {0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0},
    {0,0,0,0,1,2,3,2,2,2,1,0,0,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,0,1,4,4,4,4,4,4,4,1,0,0,0,0},
    {0,0,0,1,2,2,2,3,2,2,2,1,0,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,0,1,4,4,4,4,4,4,4,1,0,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0},
    {0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local LANTERN_PALETTE = { [1] = OUTLINE, [2] = LANTERN, [3] = LANTHI, [4] = LANTBAND }

-- poster: a framed art poster (wall item)
local POSTER = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,1,0,0},
    {0,1,2,3,3,3,3,3,3,3,3,3,2,1,0,0},
    {0,1,2,3,5,5,5,5,5,5,5,3,2,1,0,0},
    {0,1,2,3,5,5,5,5,5,5,5,3,2,1,0,0},
    {0,1,2,3,5,5,6,5,6,5,5,3,2,1,0,0},
    {0,1,2,3,5,5,5,6,5,5,5,3,2,1,0,0},
    {0,1,2,3,5,5,6,5,6,5,5,3,2,1,0,0},
    {0,1,2,3,5,5,5,5,5,5,5,3,2,1,0,0},
    {0,1,2,3,3,3,3,3,3,3,3,3,2,1,0,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,1,0,0},
    {0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local POSTER_PALETTE = { [1] = OUTLINE, [2] = WOOD, [3] = WOODHI, [5] = PAPER, [6] = INK }

------------------------------------------------------------------
-- Sequences: one tag per item, single frame each.
------------------------------------------------------------------
local SEQUENCES = {
    { name = "ball",     grid = BALL,           palette = BALL_PALETTE },
    { name = "table",    grid = TABLE,          palette = TABLE_PALETTE },
    { name = "cushion",  grid = CUSHION_SHAPE,  palette = CUSHION_PALETTE },
    { name = "plant",    grid = PLANT,          palette = PLANT_PALETTE },
    { name = "lantern",  grid = LANTERN_SHAPE,  palette = LANTERN_PALETTE },
    { name = "poster",   grid = POSTER,         palette = POSTER_PALETTE },
}

local spr = Sprite(SIDE, SIDE, ColorMode.RGB)
spr.filename = OUTPUT

local layer = spr.layers[1]
while #spr.frames < #SEQUENCES do
    spr:newEmptyFrame()
end

local frameIdx = 1
local tagBoundaries = {}
for _, seq in ipairs(SEQUENCES) do
    local img = Image(SIDE, SIDE, ColorMode.RGB)
    renderGrid(img, seq.grid, seq.palette)
    local existing = layer:cel(frameIdx)
    if existing then spr:deleteCel(existing) end
    spr:newCel(layer, frameIdx, img, Point(0, 0))
    tagBoundaries[#tagBoundaries + 1] = {
        name = seq.name, from = frameIdx, to = frameIdx
    }
    frameIdx = frameIdx + 1
end

for _, tb in ipairs(tagBoundaries) do
    local tag = spr:newTag(tb.from, tb.to)
    tag.name = tb.name
end

spr:saveAs(OUTPUT)
print(string.format("Wrote %s: %d frames, %d tags", OUTPUT, frameIdx - 1, #tagBoundaries))
