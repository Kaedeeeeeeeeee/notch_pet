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
-- Art grid stays 16×16 (the pixel sprites themselves).
local SIDE = 16
-- Render canvas is larger so vertical-motion animations (bounce airborne
-- = -3px, held/sit = +3px) and leanX (±2px) never clip the sprite's
-- head/feet/sides. 5px of transparent padding on every side gives every
-- animation ample headroom. The 16×16 art is centred within this box.
local CANVAS = 26
local OFFSET = 5

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

local function inBounds(x, y) return x >= 0 and x < CANVAS and y >= 0 and y < CANVAS end

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
-- FROG — squat body, bulging eye domes, splayed legs
--================================================================
-- Cell: 1=body 2=outline 3=highlight 4=belly 5=mouth
--       6=eye-white 7=eye-pupil 8=cheek 9=spot/wart
local FROG_BASE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  1
    {0,0,0,0,2,2,0,0,0,0,2,2,0,0,0,0},  --  2 eye dome tops
    {0,0,0,2,3,3,2,0,0,2,3,3,2,0,0,0},  --  3
    {0,0,2,3,6,7,3,2,2,3,7,6,3,2,0,0},  --  4 eyes open
    {0,0,2,3,6,7,3,3,3,3,7,6,3,2,0,0},  --  5
    {0,2,3,3,3,3,3,3,3,3,3,3,3,3,2,0},  --  6 head top
    {0,2,1,1,1,1,5,5,5,5,1,1,1,1,2,0},  --  7 wide mouth (5=mouth)
    {0,2,1,8,1,1,1,1,1,1,1,1,8,1,2,0},  --  8 cheeks
    {0,2,1,1,1,4,4,4,4,4,4,1,1,1,2,0},  --  9 belly begins
    {0,2,1,1,4,4,4,4,4,4,4,4,1,1,2,0},  -- 10
    {0,0,2,1,4,4,4,4,4,4,4,4,1,2,0,0},  -- 11
    {0,0,2,1,1,9,1,1,1,1,9,1,1,2,0,0},  -- 12 spots (cell 9)
    {0,2,2,2,1,1,2,2,2,2,1,1,2,2,2,0},  -- 13 thighs splitting
    {0,2,0,2,2,0,0,0,0,0,0,2,2,0,2,0},  -- 14 legs
    {2,2,0,0,2,2,0,0,0,0,2,2,0,0,2,2},  -- 15 feet/fingers
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  -- 16
}
local FROG_EXPR = {
    cheerful = {},
    shy      = { {4,5,6},{4,10,6},{4,6,6},{4,11,6}, {8,4,8},{8,12,8} },
    aloof    = { {3,5,2},{3,10,2}, {7,6,1},{7,13,1} },
    gluttonous = { {7,7,5},{7,8,5},{7,9,5} },
    lazy     = { {3,4,3},{3,11,3}, {3,11,6} },
    grumpy   = { {3,5,2},{3,10,2}, {6,3,2},{6,14,2} },
}
local function frogCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(90,180,80),  tint, dimK)
    elseif cell == 2 then return C(30, 70, 30)
    elseif cell == 3 then return applyTint(C(145,220,125), tint, dimK)
    elseif cell == 4 then return applyTint(C(245,240,180), tint, dimK) -- cream belly
    elseif cell == 5 then return C(130, 45, 55) -- mouth line
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,165,165)
    elseif cell == 9 then return applyTint(C(55,120,50), tint, dimK) -- darker spots
    end; return nil
end

--================================================================
-- SNAKE — reference-driven (Snake-game head + coiled body). Big
-- expressive head with 2×2 eyes featuring clear eye-whites + pupils,
-- Y-shaped forked red tongue, coiled body with alternating scale
-- bands (inspired by opengameart Snake_sprite_sheet.png). Big head
-- is what gives instant snake-recognition at tiny size.
--================================================================
-- Cell: 1=body 2=outline 3=highlight 4=belly-peek
--       5=tongue-red 6=eye-white 7=eye-pupil 8=cheek 9=dark-scales
local SNAKE_BASE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  1 (y=0)
    {0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0},  --  2 (y=1) head crown (6 wide)
    {0,0,0,0,2,3,3,3,3,3,3,2,0,0,0,0},  --  3 (y=2) head widens
    {0,0,0,2,3,6,6,3,3,6,6,3,2,0,0,0},  --  4 (y=3) 2×2 eye whites
    {0,0,0,2,3,6,7,3,3,7,6,3,2,0,0,0},  --  5 (y=4) pupils (inner = looking fwd)
    {0,0,0,2,3,3,3,3,3,3,3,3,2,0,0,0},  --  6 (y=5) chin
    {0,0,0,0,2,3,1,5,5,1,3,2,0,0,0,0},  --  7 (y=6) open mouth + tongue base
    {0,0,0,0,0,2,5,2,2,5,2,0,0,0,0,0},  --  8 (y=7) Y-forked tongue tips
    -- === Upper coil (smaller, sitting on top) ===
    {0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0},  --  9 (y=8) upper coil top (10 wide)
    {0,0,2,3,1,9,9,9,9,9,9,1,3,2,0,0},  -- 10 (y=9) upper scales (12 wide)
    {0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0},  -- 11 (y=10) tier seam (bottom of upper)
    -- === Lower coil (wider, supports the upper) ===
    {0,2,3,1,1,1,1,1,1,1,1,1,1,3,2,0},  -- 12 (y=11) lower coil top body (14)
    {2,3,1,9,9,9,9,9,9,9,9,9,9,1,3,2},  -- 13 (y=12) lower scales (16 wide)
    {2,3,1,1,1,1,1,1,1,1,1,1,1,1,3,2},  -- 14 (y=13) lower body
    {0,2,2,4,4,4,4,4,4,4,4,4,4,2,2,0},  -- 15 (y=14) yellow belly
    {0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0},  -- 16 (y=15) ground
}
local SNAKE_EXPR = {
    cheerful = {},
    -- shy: close both eyes to slits (all 8 eye cells → outline)
    shy      = { {4,6,2},{4,7,2},{4,10,2},{4,11,2},{5,6,2},{5,7,2},{5,10,2},{5,11,2} },
    -- aloof: swap pupil/white so pupils face outward (looking away)
    aloof    = { {5,6,7},{5,7,6},{5,10,6},{5,11,7} },
    -- gluttonous: widen tongue to 4px wide
    gluttonous = { {7,7,5},{7,10,5} },
    -- lazy: top row of eyes becomes highlight (droopy upper lids)
    lazy     = { {4,6,3},{4,7,3},{4,10,3},{4,11,3} },
    -- grumpy: dark brow line just above each eye
    grumpy   = { {3,6,2},{3,7,2},{3,10,2},{3,11,2} },
}
local function snakeCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(105,185,75),  tint, dimK) -- body green
    elseif cell == 2 then return C(25, 60, 25)                     -- outline
    elseif cell == 3 then return applyTint(C(150,220,110), tint, dimK) -- highlight
    elseif cell == 4 then return applyTint(C(240,225,140), tint, dimK) -- yellow belly
    elseif cell == 5 then return C(215, 45, 75)                    -- red tongue
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,165,165)
    elseif cell == 9 then return applyTint(C(55,120,45), tint, dimK) -- dark scales
    end; return nil
end

--================================================================
-- TURTLE — reference-driven (opengameart 16x16 animated turtle):
-- very horizontal body with SMALL shell (3-4 rows), clear yellow
-- belly + 2 visible legs poking down, head bumping out front-right.
-- Shell is now ~25% of height rather than 44% — this is what stops
-- it reading as a mushroom.
--================================================================
-- Cell: 1=skin(green) 2=outline 3=skin-highlight 4=shell-highlight
--       5=mouth/nose 6=eye-white 7=eye-pupil 8=cheek 9=shell-body
local TURTLE_BASE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  1 (y=0)
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  2 (y=1)
    {0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0},  --  3 (y=2) shell peak (7 wide)
    {0,0,0,2,9,4,4,4,4,4,9,2,0,0,0,0},  --  4 (y=3) shell row 2
    {0,0,2,9,4,9,9,4,9,4,9,9,2,0,0,0},  --  5 (y=4) shell row 3
    {0,0,2,9,4,4,9,9,4,9,9,4,2,0,0,0},  --  6 (y=5) shell row 4 — EXTRA for thickness
    {0,0,2,2,2,2,2,2,2,2,2,2,2,0,0,0},  --  7 (y=6) shell rim
    -- === NECK outline at x=10 clearly separates body (x=3-9) from head (x=11-15) ===
    -- === Plastron (9/4 shell pattern) on belly row ===
    -- === Tail (left): extends all the way to x=0 ===
    {0,0,0,1,1,1,1,1,1,1,2,2,2,2,2,0},  --  8 (y=7) body + NECK + head top outline
    {0,0,0,1,1,1,1,1,1,1,2,1,1,3,3,2},  --  9 (y=8) body + NECK + head body + hl
    {0,2,2,1,1,1,1,1,1,1,2,1,1,6,7,2},  -- 10 (y=9) tail top outline + body + NECK + eye
    {2,1,1,1,1,1,1,1,1,1,2,1,1,6,7,2},  -- 11 (y=10) tail body + body + NECK + eye row 2
    {0,2,2,4,9,4,9,4,9,4,2,1,1,3,5,2},  -- 12 (y=11) tail close + PLASTRON + NECK + mouth
    {0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,0},  -- 13 (y=12) body underline + head closure
    {0,0,0,2,1,2,0,0,0,0,2,1,2,0,0,0},  -- 14 (y=13) legs (back + front)
    {0,0,0,2,1,2,0,0,0,0,2,1,2,0,0,0},  -- 15 (y=14) legs
    {0,0,0,2,2,2,0,0,0,0,2,2,2,0,0,0},  -- 16 (y=15) feet on ground
}
local TURTLE_EXPR = {
    cheerful = {},
    -- shy handled by SIGNATURE (all retracted)
    shy      = {},
    -- aloof: top row of eye becomes highlight (half-lidded, looking away)
    aloof    = { {10,14,3},{10,15,3} },
    -- gluttonous: extend mouth one pixel left
    gluttonous = { {12,14,5} },
    -- lazy: both rows of eye dimmed (sleepy)
    lazy     = { {10,14,3},{10,15,3},{11,14,3},{11,15,3} },
    -- grumpy: dark brow above eye (row 9 = y=8, just above eye at y=9)
    grumpy   = { {9,14,2},{9,15,2} },
}
local function turtleCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(140,180,110), tint, dimK)    -- skin green
    elseif cell == 2 then return C(40, 45, 20)                        -- outline
    elseif cell == 3 then return applyTint(C(185,215,135), tint, dimK)-- skin highlight
    elseif cell == 4 then return applyTint(C(180,135,70), tint, dimK) -- shell highlight
    elseif cell == 5 then return C(80, 50, 30)                        -- mouth
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,165,165)
    elseif cell == 9 then return applyTint(C(110,70,35), tint, dimK)  -- shell body
    end; return nil
end

--================================================================
-- SNAIL — reference-driven (opengameart snail pack): shell DOMINATES
-- (~60% of sprite), clear 2-ring spiral pattern with center dot,
-- small body sticking out with just a tiny eye (no tall antennae).
-- This shell-first proportion is what reads as "snail" instantly.
--================================================================
-- Cell: 1=body-pink 2=outline 3=body-highlight 4=shell-highlight
--       5=mouth-dot 6=eye-white 7=eye-pupil 8=cheek 9=shell-body
local SNAIL_BASE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  1 (y=0)
    {0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0},  --  2 (y=1) shell top
    {0,0,0,2,9,4,4,4,4,4,9,2,0,0,0,0},  --  3 (y=2)
    {0,0,2,9,4,2,2,2,2,2,4,9,2,0,0,0},  --  4 (y=3) outer ring + inner starts
    {0,2,9,4,2,9,4,4,9,2,4,9,2,0,0,0},  --  5 (y=4)
    {0,2,9,4,2,9,3,9,9,2,4,9,2,0,0,0},  --  6 (y=5) center highlight (3)
    {0,2,9,4,2,9,9,9,9,2,4,9,2,0,0,0},  --  7 (y=6)
    {0,2,9,4,2,2,2,2,2,2,4,9,2,0,0,0},  --  8 (y=7) inner ring close
    {0,2,9,4,4,4,4,4,4,4,4,9,2,0,0,0},  --  9 (y=8)
    {0,0,2,9,9,9,9,9,9,9,9,2,0,0,0,0},  -- 10 (y=9) shell bottom curve
    {0,0,0,2,2,2,2,2,2,2,2,0,0,0,0,0},  -- 11 (y=10) shell rim
    {0,2,3,1,1,1,1,1,1,1,1,1,1,1,3,2},  -- 12 (y=11) body top + head right
    {2,1,1,8,1,1,1,1,1,1,1,1,1,6,7,2},  -- 13 (y=12) body + cheek + eye
    {2,1,1,1,1,1,1,1,1,1,1,1,1,1,5,2},  -- 14 (y=13) body + mouth
    {2,2,1,1,1,1,1,1,1,1,1,1,1,1,2,2},  -- 15 (y=14) body outline
    {0,2,4,4,4,4,4,4,4,4,4,4,4,4,2,0},  -- 16 (y=15) foot underside on ground
}
local SNAIL_EXPR = {
    cheerful = {},
    shy      = {}, -- handled by SIGNATURE (fully retracted)
    aloof    = { {13,14,3} }, -- pupil becomes highlight (looking away)
    gluttonous = { {14,14,5} }, -- extend mouth one pixel left
    lazy     = { {13,14,3},{13,15,3} }, -- both eye cells dimmed (sleepy)
    grumpy   = { {13,14,2},{13,15,2} }, -- eye squints to outline
}
local function snailCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(220,175,160), tint, dimK)    -- body pink-tan
    elseif cell == 2 then return C(55, 35, 30)                        -- outline
    elseif cell == 3 then return applyTint(C(245,210,195), tint, dimK)-- body highlight
    elseif cell == 4 then return applyTint(C(250,230,185), tint, dimK)-- shell highlight
    elseif cell == 5 then return C(105, 55, 50)                       -- mouth
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,175,170)
    elseif cell == 9 then return applyTint(C(210,160,85), tint, dimK) -- shell tan
    end; return nil
end

--================================================================
-- OCTOPUS — big bulb head + 6 dangling tentacles + two big eyes
--================================================================
-- Cell: 1=body-pink 2=outline 3=highlight 4=underside-pale
--       5=mouth-beak 6=eye-white 7=eye-pupil 8=cheek 9=suction-white
local OCTOPUS_BASE = {
    {0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,0},  --  1 head top
    {0,0,0,2,3,3,3,3,3,3,3,3,2,0,0,0},  --  2
    {0,0,2,3,3,3,3,3,3,3,3,3,3,2,0,0},  --  3
    {0,2,3,6,7,7,3,3,3,3,7,7,6,3,2,0},  --  4 big eyes
    {0,2,3,6,7,7,3,3,3,3,7,7,6,3,2,0},  --  5 eyes wider
    {0,2,3,3,3,3,3,8,8,3,3,3,3,3,2,0},  --  6 cheeks
    {0,2,1,1,1,1,1,5,5,1,1,1,1,1,2,0},  --  7 body + beak (5)
    {0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0},  --  8 body
    {0,0,2,1,1,1,1,1,1,1,1,1,1,2,0,0},  --  9
    {0,0,2,9,1,1,9,1,1,9,1,1,9,2,0,0},  -- 10 suction dots (9)
    {0,2,2,1,9,2,1,2,2,1,2,9,1,2,2,0},  -- 11 tentacles start
    {2,1,1,2,1,1,2,1,1,2,1,1,2,1,1,2},  -- 12 tentacles splay
    {2,9,1,2,9,1,2,9,1,2,9,1,2,9,1,2},  -- 13 suctions
    {2,1,1,2,1,1,2,1,1,2,1,1,2,1,1,2},  -- 14 tentacle tips
    {0,2,2,0,2,2,0,2,2,0,2,2,0,2,2,0},  -- 15
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  -- 16
}
local OCTOPUS_EXPR = {
    cheerful = {},
    shy      = { {4,4,6},{4,13,6}, {5,4,6},{5,13,6}, {6,7,8},{6,10,8} },
    aloof    = { {4,5,2},{4,12,2}, {4,10,1},{4,7,1} },
    gluttonous = { {6,7,5},{6,8,5},{6,9,5},{6,10,5} }, -- cheeks become mouth
    lazy     = { {4,5,3},{4,12,3}, {5,11,6} },
    grumpy   = { {4,5,2},{4,12,2}, {5,5,2},{5,12,2} },
}
local function octopusCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(240,150,165), tint, dimK) -- coral pink
    elseif cell == 2 then return C(130, 40, 55)
    elseif cell == 3 then return applyTint(C(255,195,205), tint, dimK)
    elseif cell == 4 then return applyTint(C(255,225,225), tint, dimK)
    elseif cell == 5 then return C(110, 60, 70) -- beak
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,180,185)
    elseif cell == 9 then return C(255,245,240) -- suction cup white
    end; return nil
end

--================================================================
-- SLIME — droplet blob, no limbs, big cute eyes
--================================================================
-- Cell: 1=body-teal 2=outline 3=highlight-sheen 4=inner-glow
--       5=mouth 6=eye-white 7=eye-pupil 8=cheek 9=reflection-dot
local SLIME_BASE = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  1
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  --  2
    {0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0},  --  3 head crown
    {0,0,0,0,2,3,9,3,3,3,2,0,0,0,0,0},  --  4 highlight sheen (9=reflection)
    {0,0,0,2,3,3,3,3,3,3,3,2,0,0,0,0},  --  5
    {0,0,2,3,6,7,3,3,3,7,6,3,2,0,0,0},  --  6 eyes
    {0,0,2,3,6,7,3,3,3,7,6,3,2,0,0,0},  --  7 eyes wider
    {0,2,3,3,3,3,3,5,5,3,3,3,3,2,0,0},  --  8 tiny mouth
    {0,2,1,1,8,1,1,1,1,1,1,8,1,1,2,0},  --  9 cheeks + body widens
    {0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0},  -- 10 body
    {0,2,1,1,1,4,4,4,4,4,4,1,1,1,2,0},  -- 11 inner glow
    {2,1,1,4,4,4,4,4,4,4,4,4,4,1,1,2},  -- 12 widest
    {2,1,1,4,4,4,4,4,4,4,4,4,4,1,1,2},  -- 13
    {2,2,1,1,4,4,4,4,4,4,4,4,1,1,2,2},  -- 14
    {0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0},  -- 15 ground edge
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},  -- 16
}
local SLIME_EXPR = {
    cheerful = {},
    shy      = { {6,5,6},{6,10,6}, {7,5,6},{7,10,6}, {9,5,8},{9,12,8} },
    aloof    = { {6,5,2},{6,10,2}, {8,5,1},{8,12,1} },
    gluttonous = { {8,7,5},{8,8,5} },
    lazy     = {}, -- handled by SIGNATURE (flattened pose)
    grumpy   = { {5,5,2},{5,10,2} },
}
local function slimeCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(C(100,190,210), tint, dimK) -- teal body
    elseif cell == 2 then return C(30, 75, 95)
    elseif cell == 3 then return applyTint(C(160,225,235), tint, dimK) -- sheen
    elseif cell == 4 then return applyTint(C(200,240,245), tint, dimK) -- inner glow
    elseif cell == 5 then return C(40, 80, 100) -- mouth
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return C(255,180,190)
    elseif cell == 9 then return WHITE -- pure white reflection dot
    end; return nil
end

--================================================================
-- Species registry
--================================================================
local SPECIES_DATA = {
    chick   = { base = CHICK_BASE,   expr = CHICK_EXPR,   cellColor = chickCellColor },
    cat     = { base = CAT_BASE,     expr = CAT_EXPR,     cellColor = catCellColor },
    dog     = { base = DOG_BASE,     expr = DOG_EXPR,     cellColor = dogCellColor },
    bird    = { base = BIRD_BASE,    expr = BIRD_EXPR,    cellColor = birdCellColor },
    frog    = { base = FROG_BASE,    expr = FROG_EXPR,    cellColor = frogCellColor },
    snake   = { base = SNAKE_BASE,   expr = SNAKE_EXPR,   cellColor = snakeCellColor },
    turtle  = { base = TURTLE_BASE,  expr = TURTLE_EXPR,  cellColor = turtleCellColor },
    snail   = { base = SNAIL_BASE,   expr = SNAIL_EXPR,   cellColor = snailCellColor },
    octopus = { base = OCTOPUS_BASE, expr = OCTOPUS_EXPR, cellColor = octopusCellColor },
    slime   = { base = SLIME_BASE,   expr = SLIME_EXPR,   cellColor = slimeCellColor },
}
local SPECIES_NAMES = {
    "chick","cat","dog","bird",
    "frog","snake","turtle","snail","octopus","slime",
}

--================================================================
-- Signature grids — fully custom silhouettes for a handful of
-- species × personality combos where the personality expression
-- is stronger than just an eye tweak. When a key is present here
-- it REPLACES the base+expr grid entirely.
--================================================================
-- Shy turtle: head / tail / all legs fully retracted; only the small
-- shell sits on the ground with plastron (yellow belly) peeking
-- underneath. Matches new compact side-view shell.
local TURTLE_SHY_SIG = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0},   -- shell peak
    {0,0,0,0,0,2,2,9,9,9,9,2,2,0,0,0},
    {0,0,0,0,2,9,4,9,9,4,9,9,2,0,0,0},
    {0,0,0,2,9,4,9,6,7,9,9,4,9,2,0,0},   -- tiny peeking eye in shell
    {0,0,0,2,9,9,9,4,4,9,9,9,9,2,0,0},
    {0,0,0,2,2,2,2,2,2,2,2,2,2,2,0,0},   -- shell rim
    {0,0,0,2,4,4,4,4,4,4,4,4,4,2,0,0},   -- plastron exposed
    {0,0,0,2,2,2,2,2,2,2,2,2,2,2,0,0},   -- plastron outline
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
-- Shy snail: body/head fully retracted, only the spiral shell sits
-- on the ground with plastron peeking. Matches new larger 2-ring
-- spiral aesthetic.
local SNAIL_SHY_SIG = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0},   -- shell top
    {0,0,0,2,9,4,4,4,4,4,9,2,0,0,0,0},
    {0,0,2,9,4,2,2,2,2,2,4,9,2,0,0,0},
    {0,2,9,4,2,9,4,4,9,2,4,9,2,0,0,0},
    {0,2,9,4,2,9,3,9,9,2,4,9,2,0,0,0},   -- center highlight
    {0,2,9,4,2,9,9,9,9,2,4,9,2,0,0,0},
    {0,2,9,4,2,2,2,2,2,2,4,9,2,0,0,0},
    {0,2,9,4,4,4,4,4,4,4,4,9,2,0,0,0},
    {0,0,2,9,9,9,9,9,9,9,9,2,0,0,0,0},
    {0,0,0,2,2,2,2,2,2,2,2,0,0,0,0,0},   -- shell rim
    {0,0,0,2,4,4,4,4,4,4,4,2,0,0,0,0},   -- plastron peek
    {0,0,0,2,2,2,2,2,2,2,2,2,0,0,0,0},   -- outline bottom
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
-- Lazy slime: pancake-flattened blob (wider, shorter, sleepy eyes)
local SLIME_LAZY_SIG = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,0},
    {0,0,0,2,3,9,3,3,3,3,3,3,2,0,0,0},
    {0,0,2,3,3,3,3,3,3,3,3,3,3,2,0,0},
    {0,2,3,3,2,3,3,3,3,3,3,2,3,3,2,0},  -- closed eyes (cell 2 slits)
    {2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,2},
    {2,1,1,4,4,4,4,4,4,4,4,4,4,1,1,2},
    {2,1,1,4,4,4,4,4,4,4,4,4,4,1,1,2},
    {2,2,1,1,4,4,4,4,4,4,4,4,1,1,2,2},
    {0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
-- Lazy snake: coiled flat on the ground, head lazily resting on the top
-- coil. Horizontal ellipse with the head visible on the right.
local SNAKE_LAZY_SIG = {
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    {0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0},   -- top of coil
    {0,0,2,3,1,1,1,9,1,9,1,1,1,3,2,0},
    {0,2,3,1,9,1,9,1,9,1,9,1,9,1,3,2},   -- full-width scales band
    {0,2,3,1,1,9,1,9,1,9,1,2,2,2,2,0},   -- right end has head tucked
    {0,2,2,3,1,1,9,1,9,1,1,2,3,3,2,0},
    {0,0,2,2,3,3,4,4,4,4,3,2,3,7,2,5},   -- closed eye slit + tongue
    {0,0,0,2,2,2,2,2,2,2,2,2,2,2,0,0},
    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local SIGNATURES = {
    turtle_shy = TURTLE_SHY_SIG,
    snail_shy  = SNAIL_SHY_SIG,
    slime_lazy = SLIME_LAZY_SIG,
    snake_lazy = SNAKE_LAZY_SIG,
}
local function signatureGrid(speciesKey, personality)
    return SIGNATURES[speciesKey .. "_" .. (personality or "")]
end

------------------------------------------------------------------
-- Build grid: base + personality expression overlay
------------------------------------------------------------------
local function buildGrid(speciesKey, personality)
    -- Signature (fully custom grid for a given species × personality)
    -- takes precedence over the base+overlay path. See SIGNATURES table
    -- above for the bespoke poses (shy turtle, shy snail, lazy slime,
    -- lazy snake).
    local sig = signatureGrid(speciesKey, personality)
    if sig then
        local grid = {}
        for r = 1, SIDE do
            grid[r] = {}
            for c = 1, SIDE do grid[r][c] = sig[r][c] end
        end
        return grid
    end

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
-- Per-species vertical nudge: some species' 16×16 art has its feet at
-- art y=14 with y=15 empty (legacy of the pre-26×26 design). Shifting
-- those species down by 1 pixel makes every pet's feet land on the
-- same canvas row (y=20), so the floor line is flat across all 10.
local FOOT_ADJUST = {
    bird    = 1,
    -- turtle and snail both now bottom-aligned at art y=15 (reference-
    -- driven redesigns); no per-species offset needed.
    octopus = 1,
    slime   = 1,
}

local function renderPet(img, speciesKey, personality, stage, mode, frame)
    local sp = SPECIES_DATA[speciesKey]
    local grid = buildGrid(speciesKey, personality)
    local tint = PERS_TINT[personality] or PERS_TINT.cheerful
    local dimK = (stage == "elder") and 0.85 or 1.0
    local childShrink = (stage == "child") and 1 or 0
    local cellColor = sp.cellColor
    local footAdj = FOOT_ADJUST[speciesKey] or 0

    -- DP: art-space drawPixel. All coordinates in this function are
    -- given relative to the 16×16 art grid; DP shifts them into the
    -- 26×26 canvas by OFFSET plus any species-specific footAdj so
    -- every pet's feet land on the same canvas floor row.
    local function DP(x, y, color)
        local cx, cy = x + OFFSET, y + OFFSET + footAdj
        if inBounds(cx, cy) then img:drawPixel(cx, cy, color) end
    end

    -- ------------------------------------------------------------------
    -- Sleeping: short-circuit the upright grid and paint a species-
    -- specific lying-down pose at the bottom of the canvas. Each species
    -- has a distinct silhouette (beak / ears / snout / tail feathers) so
    -- users can still tell them apart when curled up. Frame 1 is shifted
    -- 1px up for a gentle inhale; frame indexing at 1.5 fps is enforced
    -- by PetView so the breathing feels like ~2s per cycle regardless of
    -- personality. The shoulder-z pulse (3 frames small → medium → large)
    -- is inlined here since we return before the normal overlay pass.
    -- ------------------------------------------------------------------
    if mode == "sleeping" then
        local breath = (frame == 1) and -1 or 0

        -- Helper: paint a species-cell-color pixel at art-space (x, y+breath).
        -- Internally shifts to canvas space by OFFSET.
        local function p(x, y, cellType)
            DP(x, y + breath, cellColor(cellType, tint, dimK))
        end

        if speciesKey == "chick" then
            -- Plump round dumpling + orange beak pointing right.
            -- y=10: crown
            for x = 6, 9 do p(x, 10, 2) end
            -- y=11: upper head
            p(5, 11, 2)
            for x = 6, 10 do p(x, 11, 3) end
            p(11, 11, 2)
            -- y=12: widest head + closed eye
            p(4, 12, 2)
            for x = 5, 8 do p(x, 12, 3) end
            p(9, 12, 2)                     -- closed eye
            p(10, 12, 3); p(11, 12, 3)
            p(12, 12, 2)
            -- y=13: body + beak
            p(3, 13, 2)
            p(4, 13, 1); p(5, 13, 3); p(6, 13, 3); p(7, 13, 3)
            for x = 8, 12 do p(x, 13, 1) end
            p(13, 13, 2)
            p(14, 13, 5); p(15, 13, 5)      -- beak
            -- y=14: belly
            p(2, 14, 2)
            p(3, 14, 1)
            for x = 4, 11 do p(x, 14, 4) end
            p(12, 14, 1); p(13, 14, 1)
            p(14, 14, 2)
            -- y=15: base
            p(2, 15, 2)
            for x = 3, 13 do p(x, 15, 1) end
            p(14, 15, 2)

        elseif speciesKey == "cat" then
            -- Round loaf with two pointy ears and a pink nose tip.
            -- y=9: ear tips
            p(9, 9, 2); p(12, 9, 2)
            -- y=10: ears
            p(9, 10, 2); p(10, 10, 1); p(11, 10, 1); p(12, 10, 2)
            -- y=11: head crown (connects ears)
            p(4, 11, 2); p(5, 11, 2); p(6, 11, 2); p(7, 11, 2); p(8, 11, 2)
            p(9, 11, 3); p(10, 11, 3); p(11, 11, 3); p(12, 11, 3)
            p(13, 11, 2)
            -- y=12: upper body (rounded)
            p(3, 12, 2)
            for x = 4, 12 do p(x, 12, 3) end
            p(13, 12, 1); p(14, 12, 2)
            -- y=13: body + closed eye + pink nose
            p(2, 13, 2)
            p(3, 13, 1); p(4, 13, 3); p(5, 13, 3); p(6, 13, 3)
            for x = 7, 10 do p(x, 13, 1) end
            p(11, 13, 2)                    -- closed eye
            p(12, 13, 1); p(13, 13, 5)      -- pink nose
            p(14, 13, 1); p(15, 13, 2)
            -- y=14: belly
            p(2, 14, 2)
            p(3, 14, 1)
            for x = 4, 11 do p(x, 14, 4) end
            p(12, 14, 1); p(13, 14, 1); p(14, 14, 1)
            p(15, 14, 2)
            -- y=15: base
            p(2, 15, 2)
            for x = 3, 14 do p(x, 15, 1) end
            p(15, 15, 2)

        elseif speciesKey == "dog" then
            -- Rounded side pose with floppy ear draping over the face,
            -- dark nose tip, and stubby tail stub on the left.
            -- y=10: head crown
            for x = 5, 9 do p(x, 10, 2) end
            -- y=11: upper head + start of ear flop (right side)
            p(4, 11, 2)
            for x = 5, 9 do p(x, 11, 3) end
            p(10, 11, 2); p(11, 11, 9)      -- ear tip emerging
            -- y=12: head widens + ear drapes
            p(3, 12, 2)
            for x = 4, 9 do p(x, 12, 3) end
            p(10, 12, 1); p(11, 12, 9); p(12, 12, 9)  -- ear flops
            p(13, 12, 2)
            -- y=13: body + ear still hanging + snout
            p(2, 13, 2)
            p(3, 13, 9)                     -- stubby tail stub
            p(4, 13, 1); p(5, 13, 3); p(6, 13, 3); p(7, 13, 3)
            p(8, 13, 1); p(9, 13, 1)
            p(10, 13, 9); p(11, 13, 9)      -- ear continues
            p(12, 13, 1); p(13, 13, 1); p(14, 13, 2)
            -- y=14: belly + snout tip + dark nose
            p(2, 14, 2)
            p(3, 14, 1)
            for x = 4, 9 do p(x, 14, 4) end
            p(10, 14, 1); p(11, 14, 1); p(12, 14, 1); p(13, 14, 1)
            p(14, 14, 5)                    -- dark nose
            p(15, 14, 2)
            -- y=15: base
            p(2, 15, 2)
            for x = 3, 14 do p(x, 15, 1) end
            p(15, 15, 2)

        elseif speciesKey == "bird" then
            -- Rounded lying bird with tail feathers fanning left, folded
            -- wing hump on the back, and orange beak poking right.
            -- y=10: head crown
            for x = 7, 10 do p(x, 10, 2) end
            -- y=11: upper head
            p(6, 11, 2)
            for x = 7, 11 do p(x, 11, 3) end
            p(12, 11, 2)
            -- y=12: head + folded wing hump (cells 9, darker blue)
            p(5, 12, 2)
            p(6, 12, 9); p(7, 12, 9); p(8, 12, 9)       -- wing hump
            p(9, 12, 3); p(10, 12, 3); p(11, 12, 3)
            p(12, 12, 1); p(13, 12, 2)
            -- y=13: back + wing continues + closed eye
            p(1, 13, 9); p(2, 13, 9)                     -- tail feather tips
            p(3, 13, 2)
            p(4, 13, 1); p(5, 13, 9); p(6, 13, 9); p(7, 13, 9)  -- wing
            p(8, 13, 1); p(9, 13, 1); p(10, 13, 1)
            p(11, 13, 2)                                 -- closed eye
            p(12, 13, 1); p(13, 13, 1); p(14, 13, 2)
            -- y=14: belly + beak
            p(0, 14, 9); p(1, 14, 9)                     -- tail trailing
            p(2, 14, 2)
            p(3, 14, 1)
            for x = 4, 10 do p(x, 14, 4) end
            p(11, 14, 1); p(12, 14, 1)
            p(13, 14, 5); p(14, 14, 5)                   -- beak
            p(15, 14, 2)
            -- y=15: base
            p(2, 15, 2)
            for x = 3, 14 do p(x, 15, 1) end
            p(15, 15, 2)

        elseif speciesKey == "frog" then
            -- Flat-out belly-down: closed eye bumps + wide body + splayed legs
            for x = 5, 10 do p(x, 11, 2) end                         -- eye domes
            p(4, 12, 2); p(5, 12, 2); p(6, 12, 2)                    -- closed eye L
            p(9, 12, 2); p(10, 12, 2); p(11, 12, 2)                  -- closed eye R
            p(7, 12, 3); p(8, 12, 3)
            p(3, 13, 2)
            for x = 4, 11 do p(x, 13, 3) end
            p(12, 13, 2)
            p(2, 14, 2); p(3, 14, 1)
            for x = 4, 11 do p(x, 14, 4) end
            p(12, 14, 1); p(13, 14, 2)
            p(1, 15, 2); p(2, 15, 1); p(3, 15, 1)
            for x = 4, 11 do p(x, 15, 1) end
            p(12, 15, 1); p(13, 15, 1); p(14, 15, 2)

        elseif speciesKey == "snake" then
            -- Coiled flat on the ground, head nestled in the center
            for x = 4, 11 do p(x, 9, 2) end
            p(3, 10, 2); p(4, 10, 3); for x = 5, 10 do p(x, 10, 1) end; p(11, 10, 3); p(12, 10, 2)
            p(2, 11, 2); p(3, 11, 3); p(4, 11, 9); p(5, 11, 1); p(6, 11, 9); p(7, 11, 1); p(8, 11, 9); p(9, 11, 1); p(10, 11, 9); p(11, 11, 1); p(12, 11, 3); p(13, 11, 2)
            p(2, 12, 2); p(3, 12, 1); p(4, 12, 1); p(5, 12, 9); p(6, 12, 1); p(7, 12, 2); p(8, 12, 1); p(9, 12, 2); p(10, 12, 1); p(11, 12, 9); p(12, 12, 1); p(13, 12, 2)
            p(2, 13, 2); p(3, 13, 3); p(4, 13, 9); p(5, 13, 1); p(6, 13, 9); p(7, 13, 1); p(8, 13, 9); p(9, 13, 1); p(10, 13, 9); p(11, 13, 1); p(12, 13, 3); p(13, 13, 2)
            p(3, 14, 2); p(4, 14, 3); for x = 5, 10 do p(x, 14, 4) end; p(11, 14, 3); p(12, 14, 2)
            for x = 4, 11 do p(x, 15, 2) end

        elseif speciesKey == "turtle" then
            -- Side-view shell resting on the ground with plastron peeking;
            -- head/tail/legs all tucked in for sleep.
            for x = 6, 9 do p(x, 9, 2) end                                -- shell peak
            p(5, 10, 2); p(6, 10, 9); p(7, 10, 4); p(8, 10, 4); p(9, 10, 9); p(10, 10, 2)
            p(4, 11, 2); p(5, 11, 9); p(6, 11, 4); p(7, 11, 9); p(8, 11, 9); p(9, 11, 4); p(10, 11, 9); p(11, 11, 2)
            p(3, 12, 2); p(4, 12, 9); p(5, 12, 9); p(6, 12, 4); p(7, 12, 9); p(8, 12, 9); p(9, 12, 4); p(10, 12, 9); p(11, 12, 9); p(12, 12, 2)
            p(2, 13, 2); for x = 3, 12 do p(x, 13, 9) end; p(13, 13, 2)   -- widest shell
            p(2, 14, 2); for x = 3, 12 do p(x, 14, 2) end; p(13, 14, 2)   -- shell rim
            for x = 3, 12 do p(x, 15, 4) end                              -- plastron on ground

        elseif speciesKey == "snail" then
            -- Antennae retracted, shell rests sideways with foot curled
            -- underneath; shell spiral still readable.
            for x = 5, 9 do p(x, 8, 2) end
            p(4, 9, 2); p(5, 9, 9); p(6, 9, 4); p(7, 9, 4); p(8, 9, 4); p(9, 9, 9); p(10, 9, 2)
            p(3, 10, 2); p(4, 10, 9); p(5, 10, 4); p(6, 10, 9); p(7, 10, 4); p(8, 10, 9); p(9, 10, 4); p(10, 10, 9); p(11, 10, 2)
            p(2, 11, 2); p(3, 11, 9); p(4, 11, 4); p(5, 11, 2); p(6, 11, 2); p(7, 11, 2); p(8, 11, 4); p(9, 11, 9); p(10, 11, 4); p(11, 11, 9); p(12, 11, 2)
            p(2, 12, 2); p(3, 12, 9); p(4, 12, 9); p(5, 12, 2); p(6, 12, 4); p(7, 12, 2); p(8, 12, 9); p(9, 12, 4); p(10, 12, 9); p(11, 12, 9); p(12, 12, 2)
            p(2, 13, 2); p(3, 13, 9); p(4, 13, 4); p(5, 13, 2); p(6, 13, 2); p(7, 13, 9); p(8, 13, 4); p(9, 13, 9); p(10, 13, 9); p(11, 13, 4); p(12, 13, 9); p(13, 13, 2)
            for x = 2, 13 do p(x, 14, 2) end
            for x = 3, 12 do p(x, 15, 4) end

        elseif speciesKey == "octopus" then
            -- Head slumped, all tentacles furled inward around it
            for x = 5, 10 do p(x, 9, 2) end
            p(4, 10, 2); p(5, 10, 3); p(6, 10, 3); p(7, 10, 3); p(8, 10, 3); p(9, 10, 3); p(10, 10, 3); p(11, 10, 2)
            p(3, 11, 2); p(4, 11, 3); p(5, 11, 2); p(6, 11, 3); p(7, 11, 3); p(8, 11, 3); p(9, 11, 2); p(10, 11, 3); p(11, 11, 3); p(12, 11, 2)
            p(3, 12, 2); p(4, 12, 1); p(5, 12, 1); p(6, 12, 1); p(7, 12, 1); p(8, 12, 1); p(9, 12, 1); p(10, 12, 1); p(11, 12, 1); p(12, 12, 1); p(13, 12, 2)
            p(3, 13, 2); p(4, 13, 1); p(5, 13, 9); p(6, 13, 1); p(7, 13, 9); p(8, 13, 1); p(9, 13, 9); p(10, 13, 1); p(11, 13, 9); p(12, 13, 1); p(13, 13, 2)
            p(2, 14, 2); p(3, 14, 1); p(4, 14, 1); p(5, 14, 1); p(6, 14, 1); p(7, 14, 1); p(8, 14, 1); p(9, 14, 1); p(10, 14, 1); p(11, 14, 1); p(12, 14, 1); p(13, 14, 1); p(14, 14, 2)
            p(2, 15, 2); p(3, 15, 2); p(4, 15, 2); p(5, 15, 2); p(10, 15, 2); p(11, 15, 2); p(12, 15, 2); p(13, 15, 2); p(14, 15, 2)

        elseif speciesKey == "slime" then
            -- Pancake-flat blob with closed-eye slits
            for x = 4, 11 do p(x, 11, 2) end
            p(3, 12, 2); p(4, 12, 3); p(5, 12, 9); p(6, 12, 3); p(7, 12, 3); p(8, 12, 3); p(9, 12, 3); p(10, 12, 3); p(11, 12, 3); p(12, 12, 2)
            p(2, 13, 2); p(3, 13, 3); p(4, 13, 2); p(5, 13, 3); p(6, 13, 2); p(7, 13, 3); p(8, 13, 3); p(9, 13, 2); p(10, 13, 3); p(11, 13, 2); p(12, 13, 3); p(13, 13, 2)
            p(2, 14, 2); p(3, 14, 1); p(4, 14, 4); p(5, 14, 4); p(6, 14, 4); p(7, 14, 4); p(8, 14, 4); p(9, 14, 4); p(10, 14, 4); p(11, 14, 4); p(12, 14, 1); p(13, 14, 2)
            p(2, 15, 2)
            for x = 3, 12 do p(x, 15, 2) end
            p(13, 15, 2)
        end

        -- Shoulder z cycle (inlined since we return early)
        local sf = frame % 3
        if sf == 0 then
            DP(14, 1, WHITE)
        elseif sf == 1 then
            DP(13, 0, WHITE); DP(14, 0, WHITE)
            DP(13, 1, WHITE)
            DP(13, 2, WHITE); DP(14, 2, WHITE)
        else
            DP(12, 0, WHITE); DP(13, 0, WHITE); DP(14, 0, WHITE)
            DP(13, 1, WHITE); DP(12, 2, WHITE); DP(13, 2, WHITE); DP(14, 2, WHITE)
        end
        return
    end

    -- Per-mode body offsets (universal across species)
    local breathOffset = 0
    local leanX = 0

    if mode == "happy" or mode == "angry" then
        if childShrink == 0 and (frame % 2 ~= 0) then breathOffset = 1 end
    elseif mode == "bounce" then
        -- Proper hop cycle: grounded → airborne → landing. Frogs —
        -- who are literally built for jumping — hop noticeably higher
        -- than the generic pet. Signature Cheerful-Frog behaviour.
        local crouchDepth, airHeight = 1, -3
        if speciesKey == "frog" then airHeight = -5; crouchDepth = 2 end
        if frame == 0 then breathOffset = crouchDepth end
        if frame == 1 then breathOffset = airHeight end
        if frame == 2 then breathOffset = 0 end
    elseif mode == "hide" then
        -- Duck way down, tuck in
        breathOffset = 3
    elseif mode == "walk" then
        -- Alternating bob + subtle lean with stride
        if frame == 0 then breathOffset = 0; leanX = -1 end
        if frame == 1 then breathOffset = -1; leanX = 1 end
        if frame == 2 then breathOffset = 0; leanX = 1 end
        if frame == 3 then breathOffset = -1; leanX = -1 end
    elseif mode == "peck" then
        if frame == 0 then breathOffset = 1 end
        if frame == 1 then breathOffset = 3 end  -- deeper peck dive
    elseif mode == "dance" then
        -- Bigger side-to-side swing
        if frame == 0 then leanX = -2 end
        if frame == 1 and childShrink == 0 then breathOffset = -2 end  -- jump
        if frame == 2 then leanX = 2 end
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
    elseif mode == "held" then
        -- Pronounced dangle: 3px drop + exaggerated side-to-side swing
        breathOffset = 3
        if frame == 0 then leanX = -2 end
        if frame == 1 then leanX = 2 end
    end

    -- Blink logic (universal — targets eye cells 6/7)
    local blink = false
    if mode == "sleeping" or mode == "yawn" or mode == "hide" then blink = true
    elseif mode == "lookaway" then blink = true   -- overlay redraws eyes elsewhere
    elseif mode == "sit" then blink = (frame == 1)
    elseif mode == "poop_act" then blink = (frame == 1)
    elseif mode == "medic" then blink = (frame == 1)
    elseif mode == "idle" or mode == "hungry" or mode == "happy" then blink = (frame == 3)
    end

    -- Draw grid (coordinates in art-space; DP adds OFFSET)
    for row = 1, SIDE do
        for col = 1, SIDE do
            local cell = grid[row][col]
            if cell ~= 0 then
                local x = col - 1 + leanX
                local y = row - 1 + breathOffset + childShrink
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
                if drawColor then DP(x, y, drawColor) end
            end
        end
    end

    -- Hide cheeks during blink
    if blink then
        for r = 1, SIDE do for c = 1, SIDE do
            if grid[r][c] == 8 then
                local x = c - 1 + leanX
                local y = r - 1 + breathOffset + childShrink
                DP(x, y, cellColor(1, tint, dimK))
            end
        end end
    end

    -----------------------------------------------------------
    -- Mode overlays (pixel coords are art-space; DP handles OFFSET)
    -----------------------------------------------------------
    local cs = childShrink
    if mode == "hungry" then
        if math.floor(frame / 2) % 2 == 0 then
            DP(8, 0, WARN); DP(8, 1, WARN); DP(8, 3, WARN)
        end
    elseif mode == "happy" then
        if frame%2==0 then DP(1,2,SPARKLE); DP(14,3,SPARKLE)
        else DP(2,3,SPARKLE); DP(13,2,SPARKLE) end
    elseif mode == "sick" then
        if frame%2==0 then
            DP(6,0,SICK_WAVE); DP(7,1,SICK_WAVE)
            DP(8,0,SICK_WAVE); DP(9,1,SICK_WAVE)
        else
            DP(6,1,SICK_WAVE); DP(7,0,SICK_WAVE)
            DP(8,1,SICK_WAVE); DP(9,0,SICK_WAVE)
        end
    elseif mode == "curious" then
        if frame%2==0 then
            DP(13,0,QUESTION); DP(14,1,QUESTION)
            DP(13,2,QUESTION); DP(13,4,QUESTION)
        else
            DP(1,0,QUESTION); DP(2,1,QUESTION)
            DP(1,2,QUESTION); DP(1,4,QUESTION)
        end
    elseif mode == "angry" then
        if frame%2==0 then
            DP(2,0,SMOKE); DP(3,1,SMOKE)
            DP(13,0,SMOKE); DP(14,1,SMOKE)
        else
            DP(3,0,SMOKE); DP(2,1,SMOKE)
            DP(14,0,SMOKE); DP(13,1,SMOKE)
        end
        if frame%2==0 then DP(5,15,cellColor(2,tint,dimK))
        else DP(10,15,cellColor(2,tint,dimK)) end

        -- Signature Grumpy-Octopus: ink spurt below the tentacles.
        if speciesKey == "octopus" then
            local ink = C(20, 15, 25)
            if frame%2==0 then
                DP(3,15,ink); DP(4,14,ink)
                DP(11,15,ink); DP(12,14,ink)
                DP(7,15,ink); DP(8,15,ink)
            else
                DP(2,14,ink); DP(4,15,ink)
                DP(11,14,ink); DP(13,15,ink)
                DP(6,15,ink); DP(9,15,ink)
            end
        end

    -- Micro-actions
    elseif mode == "lick" then
        -- Tongue: CHEEK-colored pixels hanging below beak + sparkle
        local ty = 7 + cs + breathOffset
        if frame%2==0 then
            DP(7,ty,CHEEK); DP(8,ty+1,CHEEK)
        else
            DP(8,ty,CHEEK); DP(9,ty+1,CHEEK)
        end
        if frame == 1 then DP(13,3,SPARKLE) end
    elseif mode == "lookaway" then
        -- Full head turn: shove both eyes to one side + sweat drop
        if frame%2==0 then
            DP(9,2+cs,EYEWHITE); DP(10,2+cs,EYEDARK)
            DP(11,2+cs,EYEWHITE); DP(12,2+cs,EYEDARK)
            DP(1,3,C(140,200,240))
            DP(1,4,C(140,200,240))
        else
            DP(3,2+cs,EYEDARK); DP(4,2+cs,EYEWHITE)
            DP(5,2+cs,EYEDARK); DP(6,2+cs,EYEWHITE)
            DP(14,3,C(140,200,240))
            DP(14,4,C(140,200,240))
        end
    elseif mode == "huff" then
        if frame%2==0 then
            DP(2,0,SMOKE); DP(3,1,SMOKE); DP(4,0,SMOKE)
            DP(12,0,SMOKE); DP(13,1,SMOKE)
        else
            DP(3,0,SMOKE); DP(4,1,SMOKE)
            DP(11,1,SMOKE); DP(12,0,SMOKE); DP(13,1,SMOKE)
        end
        DP(6,1+cs,EYEDARK); DP(7,1+cs,EYEDARK)
        DP(9,1+cs,EYEDARK); DP(10,1+cs,EYEDARK)
    elseif mode == "yawn" then
        local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
        DP(7,6+cs,beakColor); DP(8,6+cs,beakColor)
        DP(9,6+cs,beakColor)
        DP(7,7+cs,beakColor); DP(8,7+cs,beakColor)
        DP(9,7+cs,beakColor)
        if frame%2==0 then
            DP(12,0,WHITE); DP(13,0,WHITE); DP(14,0,WHITE)
            DP(13,1,WHITE)
            DP(12,2,WHITE); DP(13,2,WHITE); DP(14,2,WHITE)
        end
    elseif mode == "held" then
        local bodyOut = cellColor(2, tint, dimK) or OUTLINE
        local swingDir = 0
        if frame == 0 then swingDir = -1 else swingDir = 1 end
        local legBaseY = 15
        for _, col in ipairs({6, 9}) do
            local lx = col + swingDir + leanX
            DP(lx, legBaseY, bodyOut)
            DP(lx, legBaseY-1, bodyOut)
        end
        local trail = C(230, 230, 230)
        if frame == 0 then
            DP(14,5,trail); DP(15,6,trail); DP(14,7,trail)
        else
            DP(1,5,trail); DP(0,6,trail); DP(1,7,trail)
        end
        DP(8,0,WARN); DP(8,1,WARN); DP(8,3,WARN)

    -- Ambient overlays
    elseif mode == "walk" then
        local outC = cellColor(2, tint, dimK)
        if frame==0 or frame==3 then DP(3,14+cs,outC)
        else DP(12,14+cs,outC) end
    elseif mode == "peck" then
        if frame == 1 then
            local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
            local py = 14+cs
            DP(7,py,beakColor); DP(8,py,beakColor)
        end
    elseif mode == "flap" then
        local wc = cellColor(9, tint, dimK) or cellColor(1, tint, dimK)
        local wy = 7+cs
        if frame==1 then
            DP(14,wy,wc); DP(15,wy,wc)
        elseif frame==2 then
            DP(14,wy-1,wc); DP(15,wy-1,wc); DP(14,wy,wc)
        end
    elseif mode == "dance" then
        if frame==3 then DP(2,1,SPARKLE); DP(13,1,SPARKLE) end
    elseif mode == "stretch" then
        if frame==2 then
            local wc = cellColor(9, tint, dimK) or cellColor(1, tint, dimK)
            local wy = 7+cs
            DP(0,wy,wc); DP(15,wy,wc)
        end

    -- Action feedback overlays
    elseif mode == "eat" then
        local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
        if frame==1 then
            local by = 6+cs+1
            DP(7,by,beakColor); DP(8,by,beakColor)
        end
        if frame==2 then
            local cy = 7+cs
            DP(3,cy,CHEEK); DP(12,cy,CHEEK)
        end
    elseif mode == "play_act" then
        local wc = cellColor(9, tint, dimK) or cellColor(1, tint, dimK)
        if frame==0 then
            local wy = 7+cs+1
            DP(0,wy,wc); DP(15,wy,wc)
        elseif frame==1 then
            local wy = 5+cs
            DP(0,wy,wc); DP(0,wy+1,wc)
            DP(1,wy-1,wc); DP(1,wy,wc)
            DP(14,wy-1,wc); DP(14,wy,wc)
            DP(15,wy,wc); DP(15,wy+1,wc)
        elseif frame==2 then
            DP(2,14+cs,SPARKLE); DP(13,14+cs,SPARKLE)
        end
    elseif mode == "medic" then
        local beakColor = cellColor(5, tint, dimK) or C(255,148,26)
        if frame==0 then
            DP(7,6+cs,beakColor); DP(8,6+cs,beakColor)
            DP(9,6+cs,beakColor)
        end
        if frame==2 then DP(14,2,SPARKLE) end
    elseif mode == "poop_act" then
        if frame==1 then DP(7,0,WARN); DP(8,0,WARN) end
    elseif mode == "clean_act" then
        if frame==2 then
            DP(1,2,SPARKLE); DP(14,3,SPARKLE)
            DP(3,4,SPARKLE); DP(12,2,SPARKLE)
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
            local x = col - 1 + wiggle + OFFSET
            local y = row - 1 + OFFSET
            if inBounds(x, y) then
                img:drawPixel(x, y, cell == 1 and SHELL or SHELL_OUT)
            end
        end
    end end
    img:drawPixel(6+wiggle+OFFSET, 5+OFFSET, SPECKLE)
    img:drawPixel(9+wiggle+OFFSET, 8+OFFSET, SPECKLE)
    img:drawPixel(5+wiggle+OFFSET, 10+OFFSET, SPECKLE)
end

local function renderDeparted(img, frame)
    local bright = (math.floor(frame / 2) % 2 == 0)
    local bodyC = Color{ r=217, g=204, b=179, a = bright and 128 or 77 }
    local outC  = Color{ r=255, g=255, b=255, a = bright and 89 or 55 }
    for row = 1, SIDE do for col = 1, SIDE do
        local cell = GHOST[row][col]
        local x = col - 1 + OFFSET
        local y = row - 1 + OFFSET
        if cell == 1 then img:drawPixel(x, y, bodyC)
        elseif cell == 2 then img:drawPixel(x, y, outC) end
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
    idle=4, hungry=4, happy=4, sick=3, sleeping=3, curious=4, angry=4,
    lick=3, lookaway=3, hide=3, huff=3, yawn=3, bounce=3,
    walk=4, peck=3, flap=3, dance=4, stretch=3, sit=2,
    eat=3, play_act=3, medic=3, poop_act=3, clean_act=3,
    held=2,
}
local PERSONALITY_NAMES = { "cheerful","shy","aloof","gluttonous","lazy","grumpy" }
local BASE_MODES = { "idle","hungry","happy","sick","sleeping","curious" }
local AMBIENT_MODES = { "walk","peck","flap","dance","stretch","sit" }
local ACTION_MODES = { "eat","play_act","medic","poop_act","clean_act" }
local HELD_MODES = { "held" }
local CHILD_MODES = { "idle","hungry","happy","sick","sleeping","curious",
                      "walk","peck","flap","dance","stretch","sit",
                      "eat","play_act","medic","poop_act","clean_act",
                      "held" }
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
            for _, mode in ipairs(HELD_MODES) do
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
local spr = Sprite(CANVAS, CANVAS, ColorMode.RGB)
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
        local img = Image(CANVAS, CANVAS, ColorMode.RGB)
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
