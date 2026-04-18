-- NotchPet spritesheet generator — multi-species.
--
-- Each species has ONE base body grid; personality adds subtle expression
-- overlays (1-2px). Tag convention:
--   <species>_egg_idle
--   <species>_child_<mode>
--   <species>_<personality>_<stage>_<mode>
--   <species>_departed_idle
--
-- Run via tools/sprites/build_sprites.sh from repo root.

local OUTPUT = "tools/sprites/pet.aseprite"
local SIDE = 16

------------------------------------------------------------------
-- Colors (shared palette)
------------------------------------------------------------------
local function C(r, g, b, a)
    return Color{ r = r, g = g, b = b, a = a or 255 }
end

-- Shared UI overlay colors
local OUTLINE   = C(82,  46,  13)
local EYEWHITE  = C(255, 255, 250)
local EYEDARK   = C(31,  26,  15)
local CHEEK     = C(255, 153, 148)
local WARN      = C(255, 140, 26)
local WHITE     = C(255, 255, 255)
local SICK_BELLY = C(140, 179, 77)
local SICK_WAVE  = C(130, 200, 60)
local SPARKLE    = C(255, 255, 255)
local SMOKE      = C(160, 160, 160)
local QUESTION   = C(255, 230, 100)

-- Egg / departed
local SHELL     = C(255, 247, 209)
local SHELL_OUT = C(115, 89,  26)
local SPECKLE   = C(204, 140, 77)

local function applyTint(c, tint, dimK)
    local k = dimK or 1.0
    return Color{
        r = math.max(0, math.min(255, math.floor(c.red   * tint.r * k + 0.5))),
        g = math.max(0, math.min(255, math.floor(c.green * tint.g * k + 0.5))),
        b = math.max(0, math.min(255, math.floor(c.blue  * tint.b * k + 0.5))),
        a = c.alpha
    }
end

local function inBounds(x, y) return x >= 0 and x < SIDE and y >= 0 and y < SIDE end

-- Personality tints — shared across all species (subtle)
local PERS_TINT = {
    cheerful   = { r = 1.00, g = 1.00, b = 1.00 },
    shy        = { r = 0.98, g = 0.99, b = 1.02 },
    aloof      = { r = 0.96, g = 0.98, b = 1.03 },
    gluttonous = { r = 1.02, g = 0.98, b = 0.95 },
    lazy       = { r = 0.97, g = 0.97, b = 0.96 },
    grumpy     = { r = 1.03, g = 0.96, b = 0.94 },
}

--================================================================
-- CHICK
--================================================================
-- Cell: 0=trans 1=body 2=outline 3=highlight 4=belly
--       5=beak 6=eye-white 7=eye-pupil 8=cheek 9=wing/tail
local CHICK_BASE = {
    {0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0},
    {0,0,0,0,2,3,3,3,3,3,3,2,0,0,0,0},
    {0,0,0,2,3,6,7,3,3,7,6,3,2,0,0,0},
    {0,0,2,3,6,6,7,3,3,7,6,6,3,2,0,0},
    {0,0,2,3,1,1,1,5,5,1,1,1,3,2,0,0},
    {0,2,3,1,1,1,1,5,5,1,1,1,1,9,2,0},
    {0,2,3,1,8,1,1,1,1,1,1,8,1,9,2,0},
    {0,2,3,1,1,1,1,1,1,1,1,1,1,9,2,0},
    {0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0},
    {0,2,1,1,1,4,4,4,4,4,4,1,1,1,2,0},
    {0,0,2,1,1,4,4,4,4,4,4,1,1,2,0,0},
    {0,0,2,1,1,1,4,4,4,4,1,1,1,2,0,0},
    {0,0,0,2,2,1,1,1,1,1,1,2,2,0,0,0},
    {0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0},
    {0,0,0,0,2,2,0,0,0,0,2,2,0,0,0,0},
    {0,0,0,0,2,0,0,0,0,0,0,2,0,0,0,0},
}
local CHICK_EXPR = {
    cheerful = {},
    shy      = { {3,7,6},{3,10,6}, {8,5,8},{8,12,8} },
    aloof    = { {2,7,2},{2,10,2}, {7,5,1},{7,12,1} },
    gluttonous = { {7,8,5},{7,9,5} },
    lazy     = { {3,6,3},{3,11,3}, {3,10,6} },
    grumpy   = { {2,8,2},{2,9,2} },
}
local function chickCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(255,219,89), tint, dimK)
    elseif cell == 2 then return OUTLINE
    elseif cell == 3 then return applyTint(C(255,242,153), tint, dimK)
    elseif cell == 4 then return applyTint(C(230,189,71), tint, dimK)
    elseif cell == 5 then return C(255,148,26)
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return CHEEK
    elseif cell == 9 then return applyTint(C(204,158,46), tint, dimK)
    end; return nil
end

--================================================================
-- CAT — triangle ears, slim body, curved tail
--================================================================
local CAT_BASE = {
    {0,0,0,2,0,0,0,0,0,0,0,2,0,0,0,0},  --  1 ear tips
    {0,0,0,2,2,0,0,0,0,0,2,2,0,0,0,0},  --  2 ear outer
    {0,0,0,2,1,2,2,2,2,2,1,2,0,0,0,0},  --  3 ear inner + crown
    {0,0,0,2,3,6,7,3,7,6,3,2,0,0,0,0},  --  4 eyes
    {0,0,0,2,3,6,7,3,7,6,3,2,0,0,0,0},  --  5 eyes wider
    {0,0,0,2,1,1,1,5,1,1,1,2,0,0,0,0},  --  6 nose (cell5=pink nose)
    {0,0,2,1,8,1,1,1,1,1,8,1,2,0,0,0},  --  7 cheeks + whisker area
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},  --  8 body
    {0,0,2,1,1,4,4,4,4,4,1,1,2,0,0,0},  --  9 belly
    {0,0,2,1,1,4,4,4,4,4,1,1,2,0,0,0},  -- 10 belly
    {0,0,2,1,1,1,4,4,4,1,1,1,2,9,0,0},  -- 11 lower belly + tail
    {0,0,0,2,1,1,1,1,1,1,1,2,0,9,0,0},  -- 12 lower body + tail
    {0,0,0,0,2,2,2,2,2,2,2,0,0,0,9,0},  -- 13 bottom + tail tip
    {0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0},  -- 14 paws
    {0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0},  -- 15 paw tips
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  -- 16
}
local CAT_EXPR = {
    cheerful = {},
    shy      = { {4,7,6},{4,9,6}, {8,5,8},{8,11,8} },
    aloof    = { {3,7,2},{3,9,2}, {7,5,1},{7,11,1} },
    gluttonous = { {7,7,5},{7,8,5} },
    lazy     = { {4,6,3},{4,10,3}, {4,9,6} },
    grumpy   = { {3,7,2},{3,9,2} },
}
local function catCellColor(cell, tint, dimK)
    -- Gray body palette
    if cell == 1 then return applyTint(C(180,175,170), tint, dimK)
    elseif cell == 2 then return C(70, 60, 55)
    elseif cell == 3 then return applyTint(C(210,205,200), tint, dimK)
    elseif cell == 4 then return applyTint(C(220,215,210), tint, dimK)
    elseif cell == 5 then return C(255,160,160) -- pink nose
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,170,165) -- lighter cheeks
    elseif cell == 9 then return applyTint(C(170,165,160), tint, dimK) -- tail
    end; return nil
end

--================================================================
-- DOG — floppy ears, wide snout, stubby tail
--================================================================
local DOG_BASE = {
    {0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0},  --  1 head top
    {0,0,0,0,2,3,3,3,3,3,2,0,0,0,0,0},  --  2 forehead
    {0,0,2,2,3,6,7,3,7,6,3,2,2,0,0,0},  --  3 eyes + ear start
    {0,2,9,2,3,6,7,3,7,6,3,2,9,2,0,0},  --  4 floppy ears + eyes
    {0,2,9,2,1,1,1,5,1,1,1,2,9,2,0,0},  --  5 snout/nose + ears
    {0,0,2,2,1,1,5,5,5,1,1,2,2,0,0,0},  --  6 wide mouth area + ear end
    {0,0,2,1,8,1,1,1,1,1,8,1,2,0,0,0},  --  7 cheeks
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},  --  8 body
    {0,2,1,1,1,4,4,4,4,4,1,1,1,2,0,0},  --  9 belly (wider body)
    {0,2,1,1,1,4,4,4,4,4,1,1,1,2,0,0},  -- 10 belly
    {0,0,2,1,1,1,4,4,4,1,1,1,2,0,0,0},  -- 11 lower belly
    {0,0,2,1,1,1,1,1,1,1,1,1,2,9,0,0},  -- 12 lower body + tail
    {0,0,0,2,2,2,2,2,2,2,2,2,0,9,0,0},  -- 13 bottom + tail
    {0,0,0,0,2,2,0,0,0,2,2,0,0,0,0,0},  -- 14 paws (wider)
    {0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0},  -- 15 paw tips
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  -- 16
}
local DOG_EXPR = {
    cheerful = {},
    shy      = { {3,7,6},{3,9,6}, {8,5,8},{8,11,8} },
    aloof    = { {2,7,2},{2,9,2}, {7,5,1},{7,11,1} },
    gluttonous = { {7,7,5},{7,8,5} },
    lazy     = { {3,6,3},{3,10,3}, {3,9,6} },
    grumpy   = { {2,7,2},{2,9,2} },
}
local function dogCellColor(cell, tint, dimK)
    -- Warm brown palette
    if cell == 1 then return applyTint(C(200,160,110), tint, dimK)
    elseif cell == 2 then return C(80, 55, 30)
    elseif cell == 3 then return applyTint(C(225,190,145), tint, dimK)
    elseif cell == 4 then return applyTint(C(235,210,175), tint, dimK)
    elseif cell == 5 then return C(50, 35, 25) -- dark nose
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,175,160) -- cheeks
    elseif cell == 9 then return applyTint(C(180,140,95), tint, dimK) -- ears/tail
    end; return nil
end

--================================================================
-- BIRD — thin tall body, big wings, thin legs, crest
--================================================================
local BIRD_BASE = {
    {0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0},  --  1 crest feather
    {0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0},  --  2 head top
    {0,0,0,0,2,3,3,3,3,3,2,0,0,0,0,0},  --  3 forehead
    {0,0,0,2,3,6,7,3,7,6,3,2,0,0,0,0},  --  4 eyes
    {0,0,0,2,1,1,1,5,1,1,1,2,0,0,0,0},  --  5 beak (small, pointed)
    {0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0},  --  6 neck (narrow)
    {0,0,0,9,2,1,1,1,1,1,2,9,0,0,0,0},  --  7 body + wings
    {0,0,9,9,2,1,1,1,1,1,2,9,9,0,0,0},  --  8 body + wings (wider)
    {0,0,9,9,2,1,4,4,4,1,2,9,9,0,0,0},  --  9 belly + wings
    {0,0,0,9,2,1,4,4,4,1,2,9,0,0,0,0},  -- 10 belly + wings
    {0,0,0,0,2,1,1,4,1,1,2,0,0,0,0,0},  -- 11 lower belly
    {0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0},  -- 12 lower body
    {0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0},  -- 13 bottom
    {0,0,0,0,0,0,2,0,2,0,0,0,0,0,0,0},  -- 14 thin legs
    {0,0,0,0,0,2,2,0,2,2,0,0,0,0,0,0},  -- 15 feet
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  -- 16
}
local BIRD_EXPR = {
    cheerful = {},
    shy      = { {4,7,6},{4,9,6}, {6,6,8},{6,10,8} },
    aloof    = { {3,7,2},{3,9,2} },
    gluttonous = { {6,7,5},{6,8,5} },
    lazy     = { {4,6,3},{4,10,3}, {4,9,6} },
    grumpy   = { {3,7,2},{3,9,2} },
}
local function birdCellColor(cell, tint, dimK)
    -- Sky blue palette
    if cell == 1 then return applyTint(C(120,180,220), tint, dimK)
    elseif cell == 2 then return C(50, 70, 90)
    elseif cell == 3 then return applyTint(C(160,210,240), tint, dimK)
    elseif cell == 4 then return applyTint(C(220,235,245), tint, dimK) -- white belly
    elseif cell == 5 then return C(240,160,40) -- orange beak
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,180,170) -- cheeks
    elseif cell == 9 then return applyTint(C(100,155,195), tint, dimK) -- wings
    end; return nil
end

--================================================================
-- Species registry
--================================================================
local SPECIES_DATA = {
    chick = { base = CHICK_BASE, expr = CHICK_EXPR, cellColor = chickCellColor },
    cat   = { base = CAT_BASE,   expr = CAT_EXPR,   cellColor = catCellColor },
    dog   = { base = DOG_BASE,   expr = DOG_EXPR,   cellColor = dogCellColor },
    bird  = { base = BIRD_BASE,  expr = BIRD_EXPR,  cellColor = birdCellColor },
}
local SPECIES_NAMES = { "chick", "cat", "dog", "bird" }

------------------------------------------------------------------
-- Build grid: base + personality expression overlay
------------------------------------------------------------------
local function buildGrid(speciesKey, personality)
    local sp = SPECIES_DATA[speciesKey]
    local grid = {}
    for r = 1, SIDE do
        grid[r] = {}
        for c = 1, SIDE do
            grid[r][c] = sp.base[r][c]
        end
    end
    local overlay = (sp.expr[personality]) or {}
    for _, patch in ipairs(overlay) do
        local row, col, cell = patch[1], patch[2], patch[3]
        if row >= 1 and row <= SIDE and col >= 1 and col <= SIDE then
            grid[row][col] = cell
        end
    end
    return grid
end

------------------------------------------------------------------
-- Generic pet renderer (works for any species)
------------------------------------------------------------------
local function renderPet(img, speciesKey, personality, stage, mode, frame)
    local sp = SPECIES_DATA[speciesKey]
    local grid = buildGrid(speciesKey, personality)
    local tint = PERS_TINT[personality] or PERS_TINT.cheerful
    local dimK = (stage == "elder") and 0.85 or 1.0
    local childShrink = (stage == "child") and 1 or 0
    local cellColor = sp.cellColor

    -- Per-mode body offsets (universal across species)
    local breathOffset = 0
    local leanX = 0

    if mode == "happy" or mode == "angry" or mode == "bounce" then
        if childShrink == 0 and (frame % 2 ~= 0) then breathOffset = 1 end
    elseif mode == "hide" then
        breathOffset = 1
    elseif mode == "walk" then
        if frame == 1 or frame == 3 then breathOffset = 1 end
    elseif mode == "peck" then
        if frame == 0 then breathOffset = 1 end
        if frame == 1 then breathOffset = 2 end
    elseif mode == "dance" then
        if frame == 0 then leanX = -1 end
        if frame == 2 then leanX = 1 end
        if frame == 3 and childShrink == 0 then breathOffset = -1 end
    elseif mode == "stretch" then
        if frame == 0 then breathOffset = 1 end
        if frame == 1 and childShrink == 0 then breathOffset = -1 end
    elseif mode == "sit" then
        breathOffset = 2
    elseif mode == "eat" then
        if frame == 1 then breathOffset = 1 end
    elseif mode == "play_act" then
        if frame == 0 then breathOffset = 1 end
        if frame == 1 and childShrink == 0 then breathOffset = -1 end
    elseif mode == "poop_act" then
        if frame == 0 or frame == 1 then breathOffset = 1 end
    elseif mode == "clean_act" then
        if frame == 0 then leanX = -1 end
        if frame == 1 then leanX = 1 end
    end

    -- Blink logic (universal — targets eye cells 6/7)
    local blink = false
    if mode == "sleeping" or mode == "yawn" then blink = true
    elseif mode == "sit" then blink = (frame == 1)
    elseif mode == "poop_act" then blink = (frame == 1)
    elseif mode == "medic" then blink = (frame == 1)
    elseif mode == "idle" or mode == "hungry" or mode == "happy" then blink = (frame == 3)
    end

    -- Draw grid
    for row = 1, SIDE do
        for col = 1, SIDE do
            local cell = grid[row][col]
            if cell ~= 0 then
                local x = col - 1 + leanX
                local y = row - 1 + breathOffset + childShrink
                if inBounds(x, y) then
                    local drawColor = nil
                    if blink and (cell == 6 or cell == 7) then
                        drawColor = cellColor(2, tint, dimK) -- outline = closed eye
                    elseif mode == "sick" and cell == 4 then
                        drawColor = SICK_BELLY
                    elseif mode == "sick" and (cell == 6 or cell == 7) then
                        drawColor = cellColor(2, tint, dimK)
                    elseif mode == "poop_act" and frame == 1 and cell == 8 then
                        drawColor = C(255, 120, 120)
                    else
                        drawColor = cellColor(cell, tint, dimK)
                    end
                    if drawColor then img:drawPixel(x, y, drawColor) end
                end
            end
        end
    end

    -- Hide cheeks during blink
    if blink then
        for r = 1, SIDE do for c = 1, SIDE do
            if grid[r][c] == 8 then
                local x = c - 1 + leanX
                local y = r - 1 + breathOffset + childShrink
                if inBounds(x, y) then
                    img:drawPixel(x, y, cellColor(1, tint, dimK))
                end
            end
        end end
    end

    -----------------------------------------------------------
    -- Mode overlays (universal — pixel positions at sprite top)
    -----------------------------------------------------------
    local cs = childShrink
    if mode == "hungry" then
        if math.floor(frame / 2) % 2 == 0 then
            img:drawPixel(8, 0, WARN); img:drawPixel(8, 1, WARN); img:drawPixel(8, 3, WARN)
        end
    elseif mode == "sleeping" then
        img:drawPixel(12,0,WHITE); img:drawPixel(13,0,WHITE); img:drawPixel(14,0,WHITE)
        img:drawPixel(13,1,WHITE); img:drawPixel(12,2,WHITE); img:drawPixel(13,2,WHITE); img:drawPixel(14,2,WHITE)
    elseif mode == "happy" then
        if frame%2==0 then img:drawPixel(1,2,SPARKLE); img:drawPixel(14,3,SPARKLE)
        else img:drawPixel(2,3,SPARKLE); img:drawPixel(13,2,SPARKLE) end
    elseif mode == "sick" then
        if frame%2==0 then
            img:drawPixel(6,0,SICK_WAVE); img:drawPixel(7,1,SICK_WAVE)
            img:drawPixel(8,0,SICK_WAVE); img:drawPixel(9,1,SICK_WAVE)
        else
            img:drawPixel(6,1,SICK_WAVE); img:drawPixel(7,0,SICK_WAVE)
            img:drawPixel(8,1,SICK_WAVE); img:drawPixel(9,0,SICK_WAVE)
        end
    elseif mode == "curious" then
        if frame%2==0 then
            img:drawPixel(13,0,QUESTION); img:drawPixel(14,1,QUESTION)
            img:drawPixel(13,2,QUESTION); img:drawPixel(13,4,QUESTION)
        else
            img:drawPixel(1,0,QUESTION); img:drawPixel(2,1,QUESTION)
            img:drawPixel(1,2,QUESTION); img:drawPixel(1,4,QUESTION)
        end
    elseif mode == "angry" then
        if frame%2==0 then
            img:drawPixel(2,0,SMOKE); img:drawPixel(3,1,SMOKE)
            img:drawPixel(13,0,SMOKE); img:drawPixel(14,1,SMOKE)
        else
            img:drawPixel(3,0,SMOKE); img:drawPixel(2,1,SMOKE)
            img:drawPixel(14,0,SMOKE); img:drawPixel(13,1,SMOKE)
        end
        if frame%2==0 then img:drawPixel(5,15,cellColor(2,tint,dimK))
        else img:drawPixel(10,15,cellColor(2,tint,dimK)) end

    -- Micro-actions
    elseif mode == "lick" then
        local noseColor = cellColor(5, tint, dimK) or CHEEK
        if frame%2==0 then img:drawPixel(8,6+cs,CHEEK) else img:drawPixel(9,6+cs,CHEEK) end
    elseif mode == "lookaway" then
        if frame%2==0 then
            img:drawPixel(6,2+cs,EYEWHITE); img:drawPixel(9,2+cs,EYEWHITE)
            img:drawPixel(7,2+cs,EYEDARK); img:drawPixel(10,2+cs,EYEDARK)
        end
    elseif mode == "huff" then
        if frame%2==0 then img:drawPixel(3,0,SMOKE) else img:drawPixel(12,0,SMOKE) end
    elseif mode == "yawn" then
        local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
        img:drawPixel(7,6+cs,beakColor); img:drawPixel(8,6+cs,beakColor)

    -- Ambient overlays
    elseif mode == "walk" then
        local outC = cellColor(2, tint, dimK)
        if frame==0 or frame==3 then img:drawPixel(3,14+cs,outC)
        else img:drawPixel(12,14+cs,outC) end
    elseif mode == "peck" then
        if frame == 1 then
            local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
            local py = 14+cs
            if inBounds(7,py) then img:drawPixel(7,py,beakColor) end
            if inBounds(8,py) then img:drawPixel(8,py,beakColor) end
        end
    elseif mode == "flap" then
        local wc = cellColor(9, tint, dimK) or cellColor(1, tint, dimK)
        local wy = 7+cs
        if frame==1 then
            img:drawPixel(14,wy,wc); img:drawPixel(15,wy,wc)
        elseif frame==2 then
            if inBounds(14,wy-1) then img:drawPixel(14,wy-1,wc) end
            if inBounds(15,wy-1) then img:drawPixel(15,wy-1,wc) end
            img:drawPixel(14,wy,wc)
        end
    elseif mode == "dance" then
        if frame==3 then img:drawPixel(2,1,SPARKLE); img:drawPixel(13,1,SPARKLE) end
    elseif mode == "stretch" then
        if frame==2 then
            local wc = cellColor(9, tint, dimK) or cellColor(1, tint, dimK)
            local wy = 7+cs
            img:drawPixel(0,wy,wc); img:drawPixel(15,wy,wc)
        end

    -- Action feedback overlays
    elseif mode == "eat" then
        local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
        if frame==1 then
            local by = 6+cs+1
            if inBounds(7,by) then img:drawPixel(7,by,beakColor) end
            if inBounds(8,by) then img:drawPixel(8,by,beakColor) end
        end
        if frame==2 then
            local cy = 7+cs
            if inBounds(3,cy) then img:drawPixel(3,cy,CHEEK) end
            if inBounds(12,cy) then img:drawPixel(12,cy,CHEEK) end
        end
    elseif mode == "play_act" then
        local wc = cellColor(9, tint, dimK) or cellColor(1, tint, dimK)
        if frame==0 then
            local wy = 7+cs+1
            if inBounds(0,wy) then img:drawPixel(0,wy,wc) end
            if inBounds(15,wy) then img:drawPixel(15,wy,wc) end
        elseif frame==1 then
            local wy = 5+cs
            if inBounds(0,wy) then img:drawPixel(0,wy,wc) end
            if inBounds(0,wy+1) then img:drawPixel(0,wy+1,wc) end
            if inBounds(1,wy-1) then img:drawPixel(1,wy-1,wc) end
            if inBounds(1,wy) then img:drawPixel(1,wy,wc) end
            if inBounds(14,wy-1) then img:drawPixel(14,wy-1,wc) end
            if inBounds(14,wy) then img:drawPixel(14,wy,wc) end
            if inBounds(15,wy) then img:drawPixel(15,wy,wc) end
            if inBounds(15,wy+1) then img:drawPixel(15,wy+1,wc) end
        elseif frame==2 then
            img:drawPixel(2,14+cs,SPARKLE); img:drawPixel(13,14+cs,SPARKLE)
        end
    elseif mode == "medic" then
        local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
        if frame==0 then
            img:drawPixel(7,6+cs,beakColor); img:drawPixel(8,6+cs,beakColor)
            img:drawPixel(9,6+cs,beakColor)
        end
        if frame==2 then img:drawPixel(14,2,SPARKLE) end
    elseif mode == "poop_act" then
        if frame==1 then img:drawPixel(7,0,WARN); img:drawPixel(8,0,WARN) end
    elseif mode == "clean_act" then
        if frame==2 then
            img:drawPixel(1,2,SPARKLE); img:drawPixel(14,3,SPARKLE)
            img:drawPixel(3,4,SPARKLE); img:drawPixel(12,2,SPARKLE)
        end
    end
end

------------------------------------------------------------------
-- Egg + departed (shared across species)
------------------------------------------------------------------
local EGG = {
    {0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0},
    {0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0},
    {0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0},
    {0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0},
    {0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0},
    {0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0},
    {0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0},
    {0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local GHOST = {
    {0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0},
    {0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0},
    {0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0},
    {0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0},
    {0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0},
    {0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0},
    {0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0},
    {0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}

local function renderEgg(img, frame)
    local wiggle = (math.floor(frame / 2) % 2 == 0) and 0 or 1
    for row = 1, SIDE do for col = 1, SIDE do
        local cell = EGG[row][col]
        if cell ~= 0 then
            local x = col - 1 + wiggle; local y = row - 1
            if inBounds(x, y) then
                img:drawPixel(x, y, cell == 1 and SHELL or SHELL_OUT)
            end
        end
    end end
    img:drawPixel(6+wiggle, 5, SPECKLE)
    img:drawPixel(9+wiggle, 8, SPECKLE)
    img:drawPixel(5+wiggle, 10, SPECKLE)
end

local function renderDeparted(img, frame)
    local bright = (math.floor(frame / 2) % 2 == 0)
    local bodyC = Color{ r=217, g=204, b=179, a = bright and 128 or 77 }
    local outC  = Color{ r=255, g=255, b=255, a = bright and 89 or 55 }
    for row = 1, SIDE do for col = 1, SIDE do
        local cell = GHOST[row][col]
        if cell == 1 then img:drawPixel(col-1, row-1, bodyC)
        elseif cell == 2 then img:drawPixel(col-1, row-1, outC) end
    end end
end

------------------------------------------------------------------
-- Tag catalog — iterate over all species
------------------------------------------------------------------
local SEQUENCES = {}
local function push(name, drawer, n)
    SEQUENCES[#SEQUENCES + 1] = { name = name, drawer = drawer, count = n }
end

local MODE_FRAMES = {
    idle=4, hungry=4, happy=4, sick=3, sleeping=2, curious=4, angry=4,
    lick=3, lookaway=3, hide=3, huff=3, yawn=3, bounce=3,
    walk=4, peck=3, flap=3, dance=4, stretch=3, sit=2,
    eat=3, play_act=3, medic=3, poop_act=3, clean_act=3,
}
local PERSONALITY_NAMES = { "cheerful","shy","aloof","gluttonous","lazy","grumpy" }
local BASE_MODES = { "idle","hungry","happy","sick","sleeping","curious" }
local AMBIENT_MODES = { "walk","peck","flap","dance","stretch","sit" }
local ACTION_MODES = { "eat","play_act","medic","poop_act","clean_act" }
local CHILD_MODES = { "idle","hungry","happy","sick","sleeping","curious",
                      "walk","peck","flap","dance","stretch","sit",
                      "eat","play_act","medic","poop_act","clean_act" }
local MICRO_ACTIONS = {
    cheerful={"bounce"}, shy={"hide"}, aloof={"lookaway"},
    gluttonous={"lick"}, lazy={"yawn"}, grumpy={"huff"},
}

for _, sp in ipairs(SPECIES_NAMES) do
    -- Egg
    push(sp .. "_egg_idle", function(img, f) renderEgg(img, f) end, 4)

    -- Child (cheerful expression only)
    for _, mode in ipairs(CHILD_MODES) do
        push(sp .. "_child_" .. mode, function(img, f)
            renderPet(img, sp, "cheerful", "child", mode, f)
        end, MODE_FRAMES[mode])
    end

    -- Adult + Elder
    for _, pers in ipairs(PERSONALITY_NAMES) do
        for _, stage in ipairs({"adult","elder"}) do
            for _, mode in ipairs(BASE_MODES) do
                push(sp.."_"..pers.."_"..stage.."_"..mode, function(img, f)
                    renderPet(img, sp, pers, stage, mode, f)
                end, MODE_FRAMES[mode])
            end
            if pers == "grumpy" then
                push(sp.."_grumpy_"..stage.."_angry", function(img, f)
                    renderPet(img, sp, "grumpy", stage, "angry", f)
                end, MODE_FRAMES.angry)
            end
            for _, mode in ipairs(AMBIENT_MODES) do
                push(sp.."_"..pers.."_"..stage.."_"..mode, function(img, f)
                    renderPet(img, sp, pers, stage, mode, f)
                end, MODE_FRAMES[mode])
            end
            for _, mode in ipairs(ACTION_MODES) do
                push(sp.."_"..pers.."_"..stage.."_"..mode, function(img, f)
                    renderPet(img, sp, pers, stage, mode, f)
                end, MODE_FRAMES[mode])
            end
            local micros = MICRO_ACTIONS[pers] or {}
            for _, micro in ipairs(micros) do
                push(sp.."_"..pers.."_"..stage.."_"..micro, function(img, f)
                    renderPet(img, sp, pers, stage, micro, f)
                end, MODE_FRAMES[micro])
            end
        end
    end

    -- Departed
    push(sp .. "_departed_idle", function(img, f) renderDeparted(img, f) end, 2)
end

------------------------------------------------------------------
-- Build sprite document
------------------------------------------------------------------
local spr = Sprite(SIDE, SIDE, ColorMode.RGB)
spr.filename = OUTPUT

local layer = spr.layers[1]
local totalFrames = 0
for _, seq in ipairs(SEQUENCES) do totalFrames = totalFrames + seq.count end

while #spr.frames < totalFrames do spr:newEmptyFrame() end

local frameIdx = 1
local tagBoundaries = {}
for _, seq in ipairs(SEQUENCES) do
    local from = frameIdx
    for local_f = 0, seq.count - 1 do
        local img = Image(SIDE, SIDE, ColorMode.RGB)
        seq.drawer(img, local_f)
        local existing = layer:cel(frameIdx)
        if existing then spr:deleteCel(existing) end
        spr:newCel(layer, frameIdx, img, Point(0, 0))
        frameIdx = frameIdx + 1
    end
    tagBoundaries[#tagBoundaries + 1] = { name = seq.name, from = from, to = frameIdx - 1 }
end

for _, tb in ipairs(tagBoundaries) do
    local tag = spr:newTag(tb.from, tb.to)
    tag.name = tb.name
end

spr:saveAs(OUTPUT)
print(string.format("Wrote %s: %d frames, %d tags", OUTPUT, totalFrames, #tagBoundaries))
