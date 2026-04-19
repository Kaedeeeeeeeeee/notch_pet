-- NotchPet cursor generator. Produces three 16x16 pixel-art hand cursors
-- used by PetCursors.swift when the mouse hovers the pet in the room view.
--
-- Output: tools/sprites/cursor_<name>.aseprite (intermediate) which build
-- script then exports to NotchPet/Assets/Cursors/<name>.png.
--
-- Cells:
--   0 = transparent
--   1 = outline (dark brown)
--   2 = skin base (peach)
--   3 = skin shadow (darker peach)
--   4 = cuff / wrist accent (blue)
--   5 = sparkle (white)

local SIDE = 16

local function C(r,g,b,a) return Color{ r=r, g=g, b=b, a=a or 255 } end
local OUTLINE = C(46, 30, 20)
local SKIN    = C(255, 210, 172)
local SHADOW  = C(226, 168, 125)
local CUFF    = C(90, 140, 200)
local SPARKLE = C(255, 250, 220)

local function palette(cell)
    if cell == 1 then return OUTLINE
    elseif cell == 2 then return SKIN
    elseif cell == 3 then return SHADOW
    elseif cell == 4 then return CUFF
    elseif cell == 5 then return SPARKLE
    else return nil end
end

-- Open hand — pointing index finger up-left. Hotspot at fingertip (3, 1).
local OPEN = {
    {0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0},
    {0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0},
    {0,0,1,2,2,1,1,0,1,1,0,0,0,0,0,0},
    {0,0,1,2,2,2,2,1,2,2,1,1,0,0,0,0},
    {0,0,1,2,2,2,2,2,2,2,1,2,1,1,0,0},
    {0,0,1,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,0,0,1,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,0,0,1,2,2,2,2,2,2,2,2,2,3,1,0},
    {0,0,0,0,1,2,2,2,2,2,2,2,2,3,1,0},
    {0,0,0,0,1,2,2,2,2,2,2,2,3,3,1,0},
    {0,0,0,0,1,2,2,2,2,2,2,3,3,1,0,0},
    {0,0,0,0,1,4,4,4,4,4,4,4,1,0,0,0},
    {0,0,0,0,0,1,4,4,4,4,4,4,1,0,0,0},
    {0,0,0,0,0,1,4,4,4,4,4,1,0,0,0,0},
    {0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0},
}

-- Closed fist — knuckles toward upper-left. Hotspot roughly at knuckle (5, 4).
local CLOSED = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,1,1,0,1,1,0,0,0,0,0,0,0},
    {0,0,0,1,2,2,1,2,2,1,0,0,0,0,0,0},
    {0,0,1,2,2,2,2,2,2,2,1,1,0,0,0,0},
    {0,0,1,2,3,2,2,3,2,2,2,2,1,0,0,0},
    {0,1,1,2,2,2,2,2,2,2,2,2,2,1,0,0},
    {0,1,2,2,2,2,2,2,2,2,3,2,2,1,0,0},
    {0,1,2,2,2,2,2,3,3,2,3,2,2,2,1,0},
    {0,1,2,2,3,3,2,2,2,2,2,2,2,2,1,0},
    {0,1,2,2,3,2,2,2,2,2,2,2,2,3,1,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,3,3,1,0},
    {0,0,1,2,2,2,2,2,2,2,2,3,3,1,0,0},
    {0,0,1,4,4,4,4,4,4,4,4,4,1,0,0,0},
    {0,0,1,4,4,4,4,4,4,4,4,4,1,0,0,0},
    {0,0,0,1,4,4,4,4,4,4,4,1,0,0,0,0},
    {0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0},
}

-- Petting hand — fingers down, two sparkles. Hotspot at fingertip (5, 10).
local PET = {
    {0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0},
    {0,0,0,0,1,4,4,4,4,4,4,1,0,0,0,0},
    {0,0,0,0,1,4,4,4,4,4,4,1,0,0,0,0},
    {0,0,0,0,1,2,2,2,2,2,2,1,0,0,0,0},
    {0,0,0,1,2,2,2,2,2,2,2,2,1,0,0,0},
    {0,0,1,2,2,2,2,2,2,2,2,2,2,1,0,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,1,2,2,2,2,2,2,2,2,2,2,2,2,1,0},
    {0,0,1,2,2,2,2,2,2,2,2,2,2,1,0,0},
    {0,0,0,1,2,2,1,2,2,1,2,2,1,0,0,0},
    {0,0,0,1,2,3,1,2,3,1,2,3,1,0,0,0},
    {0,0,0,0,1,1,0,1,1,0,1,1,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {5,0,0,0,0,0,0,0,0,0,0,0,0,0,5,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,5,0,0,0,0,0,0,0,0,0,0,0,5,0,0},
}

local function drawGrid(img, grid)
    for row = 1, SIDE do
        for col = 1, SIDE do
            local c = palette(grid[row][col])
            if c then img:drawPixel(col - 1, row - 1, c) end
        end
    end
end

local function buildSprite(path, grid)
    local spr = Sprite(SIDE, SIDE, ColorMode.RGB)
    spr.filename = path
    local layer = spr.layers[1]
    local img = Image(SIDE, SIDE, ColorMode.RGB)
    drawGrid(img, grid)
    local existing = layer:cel(1)
    if existing then spr:deleteCel(existing) end
    spr:newCel(layer, 1, img, Point(0, 0))
    spr:saveAs(path)
end

buildSprite("tools/sprites/cursor_hand_open.aseprite",   OPEN)
buildSprite("tools/sprites/cursor_hand_closed.aseprite", CLOSED)
buildSprite("tools/sprites/cursor_hand_pet.aseprite",    PET)
