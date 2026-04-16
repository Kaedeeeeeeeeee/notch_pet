-- NotchPet spritesheet generator.
--
-- Species-aware architecture. Each species has ONE shared base body;
-- personality adds only subtle expression overlays (1-2px eye/mouth
-- tweaks). Tag naming convention:
--
--   chick_egg_idle
--   chick_child_<mode>
--   chick_<personality>_<stage>_<mode>   e.g. chick_shy_adult_idle
--   chick_<personality>_<stage>_<micro>  e.g. chick_lazy_adult_yawn
--   grumpy_<stage>_angry  → chick_grumpy_<stage>_angry
--   chick_departed_idle
--
-- Run via tools/sprites/build_sprites.sh from repo root.

local OUTPUT = "tools/sprites/pet.aseprite"
local SIDE = 16

------------------------------------------------------------------
-- Colors
------------------------------------------------------------------
local function C(r, g, b, a)
    return Color{ r = r, g = g, b = b, a = a or 255 }
end

local BODY      = C(255, 219, 89)
local HIGHLIGHT = C(255, 242, 153)
local BELLY     = C(230, 189, 71)
local WING      = C(204, 158, 46)
local OUTLINE   = C(82,  46,  13)
local BEAK      = C(255, 148, 26)
local EYEWHITE  = C(255, 255, 250)
local EYEDARK   = C(31,  26,  15)
local CHEEK     = C(255, 153, 148)
local WARN      = C(255, 140, 26)
local WHITE     = C(255, 255, 255)

local SHELL     = C(255, 247, 209)
local SHELL_OUT = C(115, 89,  26)
local SPECKLE   = C(204, 140, 77)

local SICK_BELLY = C(140, 179, 77)
local SICK_WAVE  = C(130, 200, 60)
local SPARKLE    = C(255, 255, 255)
local SMOKE      = C(160, 160, 160)
local QUESTION   = C(255, 230, 100)

-- Per-personality tint biases. Very subtle now — personality is meant
-- to be discoverable through careful observation, not at a glance.
local PERSONALITY_TINT = {
    cheerful   = { r = 1.00, g = 1.00, b = 1.00 },  -- baseline
    shy        = { r = 0.98, g = 0.99, b = 1.02 },  -- barely cooler
    aloof      = { r = 0.96, g = 0.98, b = 1.03 },  -- slightly cool
    gluttonous = { r = 1.02, g = 0.98, b = 0.95 },  -- barely warmer
    lazy       = { r = 0.97, g = 0.97, b = 0.96 },  -- slightly muted
    grumpy     = { r = 1.03, g = 0.96, b = 0.94 },  -- barely warm
}

local function applyTint(c, tint, dimK)
    local k = dimK or 1.0
    return Color{
        r = math.max(0, math.min(255, math.floor(c.red   * tint.r * k + 0.5))),
        g = math.max(0, math.min(255, math.floor(c.green * tint.g * k + 0.5))),
        b = math.max(0, math.min(255, math.floor(c.blue  * tint.b * k + 0.5))),
        a = c.alpha
    }
end

local function inBounds(x, y)
    return x >= 0 and x < SIDE and y >= 0 and y < SIDE
end

------------------------------------------------------------------
-- Shared chick base body. ALL personalities use this same grid.
-- Cell legend: 0=transparent 1=body 2=outline 3=highlight
-- 4=belly 5=beak 6=eye-white 7=eye-pupil 8=cheek 9=wing
------------------------------------------------------------------
local CHICK_BASE = {
    --       1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6
    {0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0},  --  1  crown outline
    {0,0,0,0,2,3,3,3,3,3,3,2,0,0,0,0},  --  2  highlight
    {0,0,0,2,3,6,7,3,3,7,6,3,2,0,0,0},  --  3  eyes: L(6W,7P) gap(8,9) R(10P,11W)
    {0,0,2,3,6,6,7,3,3,7,6,6,3,2,0,0},  --  4  wider eye-whites
    {0,0,2,3,1,1,1,5,5,1,1,1,3,2,0,0},  --  5  beak
    {0,2,3,1,1,1,1,5,5,1,1,1,1,9,2,0},  --  6  beak + wing
    {0,2,3,1,8,1,1,1,1,1,1,8,1,9,2,0},  --  7  cheeks(col5,col12)
    {0,2,3,1,1,1,1,1,1,1,1,1,1,9,2,0},  --  8  body
    {0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0},  --  9  body
    {0,2,1,1,1,4,4,4,4,4,4,1,1,1,2,0},  -- 10  belly
    {0,0,2,1,1,4,4,4,4,4,4,1,1,2,0,0},  -- 11  belly
    {0,0,2,1,1,1,4,4,4,4,1,1,1,2,0,0},  -- 12  lower belly
    {0,0,0,2,2,1,1,1,1,1,1,2,2,0,0,0},  -- 13  lower body
    {0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0},  -- 14  bottom outline
    {0,0,0,0,2,2,0,0,0,0,2,2,0,0,0,0},  -- 15  feet
    {0,0,0,0,2,0,0,0,0,0,0,2,0,0,0,0},  -- 16  feet tips
}
-- Eye positions (1-indexed cols): left pupil=7, right pupil=10
-- Gap between eyes: cols 8-9 (highlight)
-- Eye whites: left at 6,11; wider whites in row 4 at 5-6,11-12

------------------------------------------------------------------
-- Personality expression overlays. Each is a sparse list of
-- {row, col, cell} that overwrite base grid cells. Only 1-2px
-- differences so the pet still looks like the same chick.
--
-- Eye reference (row 3): col6=W col7=P  ··  col10=P col11=W
-- Eye reference (row 4): col5=W col6=W col7=P  ··  col10=P col11=W col12=W
------------------------------------------------------------------
local EXPRESSION_OVERLAY = {
    cheerful = {},  -- baseline, no changes

    -- Shy: pupils shifted down 1 row (row3→row4 only), enlarged cheeks
    shy = {
        { 3, 7, 6 }, { 3, 10, 6 },   -- clear row-3 pupils → eye-white (pupils only in row 4 now)
        -- Extra cheek pixel one row below existing cheeks
        { 8, 5, 8 }, { 8, 12, 8 },
    },

    -- Aloof: half-lidded eyes — outline pixel directly above each pupil
    aloof = {
        { 2, 7, 2 }, { 2, 10, 2 },   -- dark eyelid marks above each eye
        -- Remove cheeks for a colder look
        { 7, 5, 1 }, { 7, 12, 1 },
    },

    -- Gluttonous: slightly open beak — extend beak 1px down into body row
    gluttonous = {
        { 7, 8, 5 }, { 7, 9, 5 },
    },

    -- Lazy: squinty half-closed eyes — narrow outer whites, shrink one pupil
    lazy = {
        { 3, 6, 3 }, { 3, 11, 3 },   -- outer eye-whites → highlight (eyes appear smaller)
        { 3, 10, 6 },                  -- right pupil → eye-white (right eye half-shut)
    },

    -- Grumpy: furrowed brow — outline marks in the gap between eyes
    grumpy = {
        { 2, 8, 2 }, { 2, 9, 2 },   -- dark pixels above gap = angry furrowed brow
    },
}

------------------------------------------------------------------
-- Egg + departed grids (shared, no personality)
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

------------------------------------------------------------------
-- Cell → color lookup. Body-family cells take the personality tint.
------------------------------------------------------------------
local function chickCellColor(cell, tint, dimK)
    if cell == 1 then return applyTint(BODY,      tint, dimK)
    elseif cell == 2 then return OUTLINE
    elseif cell == 3 then return applyTint(HIGHLIGHT, tint, dimK)
    elseif cell == 4 then return applyTint(BELLY,     tint, dimK)
    elseif cell == 5 then return BEAK
    elseif cell == 6 then return EYEWHITE
    elseif cell == 7 then return EYEDARK
    elseif cell == 8 then return CHEEK
    elseif cell == 9 then return applyTint(WING,      tint, dimK)
    end
    return nil
end

------------------------------------------------------------------
-- Build an effective grid by applying a personality's expression
-- overlay on top of the shared base body.
------------------------------------------------------------------
local function buildGrid(personality)
    -- Deep copy the base grid
    local grid = {}
    for r = 1, SIDE do
        grid[r] = {}
        for c = 1, SIDE do
            grid[r][c] = CHICK_BASE[r][c]
        end
    end
    -- Apply sparse overlay
    local overlay = EXPRESSION_OVERLAY[personality] or {}
    for _, patch in ipairs(overlay) do
        local row, col, cell = patch[1], patch[2], patch[3]
        if row >= 1 and row <= SIDE and col >= 1 and col <= SIDE then
            grid[row][col] = cell
        end
    end
    return grid
end

------------------------------------------------------------------
-- Chick drawer.
--   personality = "cheerful"|"shy"|"aloof"|"gluttonous"|"lazy"|"grumpy"
--   stage       = "child"|"adult"|"elder"
--   mode        = "idle"|"hungry"|"happy"|"sick"|"sleeping"|"curious"|"angry"
--                 + micro-actions: "lick"|"lookaway"|"hide"|"huff"|"yawn"|"bounce"
--                 + ambient: "walk"|"peck"|"flap"|"dance"|"stretch"|"sit"
--                 + action feedback: "eat"|"play_act"|"medic"|"poop_act"|"clean_act"
------------------------------------------------------------------
local function renderChick(img, personality, stage, mode, frame)
    local grid = buildGrid(personality)
    local tint = PERSONALITY_TINT[personality] or PERSONALITY_TINT.cheerful
    local dimK = (stage == "elder") and 0.85 or 1.0
    local childShrink = (stage == "child") and 1 or 0

    ---------------------------------------------------------------
    -- Per-mode body offsets
    ---------------------------------------------------------------
    local breathOffset = 0
    local leanX = 0

    -- Existing modes
    if mode == "happy" or mode == "angry" or mode == "bounce" then
        if childShrink == 0 and (frame % 2 ~= 0) then
            breathOffset = 1
        end
    elseif mode == "hide" then
        breathOffset = 1

    -- Ambient behavior offsets
    elseif mode == "walk" then
        -- Slight bob while walking
        if frame == 1 or frame == 3 then breathOffset = 1 end
    elseif mode == "peck" then
        -- Head dips progressively
        if frame == 0 then breathOffset = 1 end
        if frame == 1 then breathOffset = 2 end
        -- frame 2: back up (0)
    elseif mode == "dance" then
        if frame == 0 then leanX = -1 end
        if frame == 2 then leanX = 1 end
        if frame == 3 and childShrink == 0 then breathOffset = -1 end -- hop
    elseif mode == "stretch" then
        if frame == 0 then breathOffset = 1 end     -- scrunch
        if frame == 1 and childShrink == 0 then breathOffset = -1 end -- tall
    elseif mode == "sit" then
        breathOffset = 2  -- squat low, hides feet
    elseif mode == "flap" then
        -- no body offset, wing animation in overlay

    -- Action feedback offsets
    elseif mode == "eat" then
        if frame == 1 then breathOffset = 1 end     -- head dips to eat
    elseif mode == "play_act" then
        if frame == 0 then breathOffset = 1 end     -- crouch
        if frame == 1 and childShrink == 0 then breathOffset = -1 end -- jump
    elseif mode == "medic" then
        -- no body offset, beak animation in overlay
    elseif mode == "poop_act" then
        if frame == 0 or frame == 1 then breathOffset = 1 end -- squat
    elseif mode == "clean_act" then
        if frame == 0 then leanX = -1 end
        if frame == 1 then leanX = 1 end
    end

    ---------------------------------------------------------------
    -- Blink logic
    ---------------------------------------------------------------
    local blink = false
    if mode == "sleeping" or mode == "yawn" then
        blink = true
    elseif mode == "sit" then
        blink = (frame == 1)
    elseif mode == "poop_act" then
        blink = (frame == 1)  -- straining face
    elseif mode == "medic" then
        blink = (frame == 1)  -- swallowing
    elseif mode == "idle" or mode == "hungry" or mode == "happy" then
        blink = (frame == 3)
    end

    ---------------------------------------------------------------
    -- Draw grid with offsets
    ---------------------------------------------------------------
    for row = 1, SIDE do
        for col = 1, SIDE do
            local cell = grid[row][col]
            if cell ~= 0 then
                local x = col - 1 + leanX
                local y = row - 1 + breathOffset + childShrink
                if inBounds(x, y) then
                    local drawColor = nil
                    if blink and (cell == 6 or cell == 7) then
                        drawColor = OUTLINE
                    elseif mode == "sick" and cell == 4 then
                        drawColor = SICK_BELLY
                    elseif mode == "sick" and (cell == 6 or cell == 7) then
                        drawColor = OUTLINE
                    elseif mode == "poop_act" and frame == 1 and cell == 8 then
                        -- Redder cheeks during strain
                        drawColor = C(255, 120, 120)
                    else
                        drawColor = chickCellColor(cell, tint, dimK)
                    end
                    if drawColor then
                        img:drawPixel(x, y, drawColor)
                    end
                end
            end
        end
    end

    -- Hide cheeks during blink
    if blink then
        for cheekRow = 1, SIDE do
            for cheekCol = 1, SIDE do
                if grid[cheekRow][cheekCol] == 8 then
                    local x = cheekCol - 1 + leanX
                    local y = cheekRow - 1 + breathOffset + childShrink
                    if inBounds(x, y) then
                        img:drawPixel(x, y, applyTint(BODY, tint, dimK))
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------
    -- Mode-specific pixel overlays
    ---------------------------------------------------------------
    if mode == "hungry" then
        if math.floor(frame / 2) % 2 == 0 then
            img:drawPixel(8, 0, WARN)
            img:drawPixel(8, 1, WARN)
            img:drawPixel(8, 3, WARN)
        end
    elseif mode == "sleeping" then
        img:drawPixel(12, 0, WHITE)
        img:drawPixel(13, 0, WHITE)
        img:drawPixel(14, 0, WHITE)
        img:drawPixel(13, 1, WHITE)
        img:drawPixel(12, 2, WHITE)
        img:drawPixel(13, 2, WHITE)
        img:drawPixel(14, 2, WHITE)
    elseif mode == "happy" then
        if frame % 2 == 0 then
            img:drawPixel(1, 2, SPARKLE)
            img:drawPixel(14, 3, SPARKLE)
        else
            img:drawPixel(2, 3, SPARKLE)
            img:drawPixel(13, 2, SPARKLE)
        end
    elseif mode == "sick" then
        if frame % 2 == 0 then
            img:drawPixel(6, 0, SICK_WAVE)
            img:drawPixel(7, 1, SICK_WAVE)
            img:drawPixel(8, 0, SICK_WAVE)
            img:drawPixel(9, 1, SICK_WAVE)
        else
            img:drawPixel(6, 1, SICK_WAVE)
            img:drawPixel(7, 0, SICK_WAVE)
            img:drawPixel(8, 1, SICK_WAVE)
            img:drawPixel(9, 0, SICK_WAVE)
        end
    elseif mode == "curious" then
        if frame % 2 == 0 then
            img:drawPixel(13, 0, QUESTION)
            img:drawPixel(14, 1, QUESTION)
            img:drawPixel(13, 2, QUESTION)
            img:drawPixel(13, 4, QUESTION)
        else
            img:drawPixel(1, 0, QUESTION)
            img:drawPixel(2, 1, QUESTION)
            img:drawPixel(1, 2, QUESTION)
            img:drawPixel(1, 4, QUESTION)
        end
    elseif mode == "angry" then
        if frame % 2 == 0 then
            img:drawPixel(2, 0, SMOKE)
            img:drawPixel(3, 1, SMOKE)
            img:drawPixel(13, 0, SMOKE)
            img:drawPixel(14, 1, SMOKE)
        else
            img:drawPixel(3, 0, SMOKE)
            img:drawPixel(2, 1, SMOKE)
            img:drawPixel(14, 0, SMOKE)
            img:drawPixel(13, 1, SMOKE)
        end
        if frame % 2 == 0 then
            img:drawPixel(5, 15, OUTLINE)
        else
            img:drawPixel(10, 15, OUTLINE)
        end
    -- Micro-action overlays
    elseif mode == "lick" then
        -- Gluttonous: tongue flicks out below beak (pink pixel)
        if frame % 2 == 0 then
            img:drawPixel(8, 6, CHEEK)   -- center below beak
        else
            img:drawPixel(9, 6, CHEEK)   -- offset right
        end
    elseif mode == "lookaway" then
        -- Aloof: pupils shift right (looking away). Cover old pupils
        -- with eye-white, draw new ones 1px to the right.
        if frame % 2 == 0 then
            img:drawPixel(6, 2, EYEWHITE)   -- cover left pupil (x=6,y=2)
            img:drawPixel(9, 2, EYEWHITE)   -- cover right pupil (x=9,y=2)
            img:drawPixel(7, 2, EYEDARK)    -- left pupil shifted right (into gap)
            img:drawPixel(10, 2, EYEDARK)   -- right pupil shifted right
        end
    elseif mode == "huff" then
        -- Grumpy: small smoke puff above head, alternating sides
        if frame % 2 == 0 then
            img:drawPixel(3, 0, SMOKE)
        else
            img:drawPixel(12, 0, SMOKE)
        end
    elseif mode == "yawn" then
        -- Lazy: beak opens wide — extra beak pixels below normal row
        img:drawPixel(7, 6, BEAK)
        img:drawPixel(8, 6, BEAK)

    ---------------------------------------------------------------
    -- Ambient behavior overlays
    ---------------------------------------------------------------
    elseif mode == "walk" then
        -- Alternating foot extension for walk cycle
        local cs = childShrink
        if frame == 0 or frame == 3 then
            img:drawPixel(3, 14 + cs, OUTLINE)    -- left foot forward
        elseif frame == 1 or frame == 2 then
            img:drawPixel(12, 14 + cs, OUTLINE)   -- right foot forward
        end
    elseif mode == "peck" then
        -- Frame 1: beak touches ground level
        if frame == 1 then
            local py = 14 + childShrink
            if inBounds(7, py) then img:drawPixel(7, py, BEAK) end
            if inBounds(8, py) then img:drawPixel(8, py, BEAK) end
        end
    elseif mode == "flap" then
        -- Wing extends outward progressively
        local wy = 7 + childShrink  -- wing row y
        if frame == 1 then
            img:drawPixel(14, wy, WING and applyTint(WING, tint, dimK) or OUTLINE)
            img:drawPixel(15, wy, applyTint(WING, tint, dimK))
        elseif frame == 2 then
            img:drawPixel(14, wy - 1, applyTint(WING, tint, dimK))
            img:drawPixel(15, wy - 1, applyTint(WING, tint, dimK))
            img:drawPixel(14, wy, applyTint(WING, tint, dimK))
        end
    elseif mode == "dance" then
        -- Sparkle on hop frame
        if frame == 3 then
            img:drawPixel(2, 1, SPARKLE)
            img:drawPixel(13, 1, SPARKLE)
        end
    elseif mode == "stretch" then
        -- Wings out on frame 2
        if frame == 2 then
            local wy = 7 + childShrink
            img:drawPixel(0, wy, applyTint(WING, tint, dimK))
            img:drawPixel(15, wy, applyTint(WING, tint, dimK))
        end

    ---------------------------------------------------------------
    -- Action feedback overlays
    ---------------------------------------------------------------
    elseif mode == "eat" then
        -- Frame 1: beak open (extra beak pixel below)
        if frame == 1 then
            local by = 6 + childShrink + 1  -- below beak at dipped position
            if inBounds(7, by) then img:drawPixel(7, by, BEAK) end
            if inBounds(8, by) then img:drawPixel(8, by, BEAK) end
        end
        -- Frame 2: happy cheek puff (extra cheek pixels)
        if frame == 2 then
            local cy = 7 + childShrink
            if inBounds(3, cy) then img:drawPixel(3, cy, CHEEK) end
            if inBounds(12, cy) then img:drawPixel(12, cy, CHEEK) end
        end
    elseif mode == "play_act" then
        -- Frame 1: wing flap during jump
        if frame == 1 then
            local wy = 6 + childShrink  -- shifted up with jump
            if inBounds(0, wy) then img:drawPixel(0, wy, applyTint(WING, tint, dimK)) end
            if inBounds(15, wy) then img:drawPixel(15, wy, applyTint(WING, tint, dimK)) end
        end
        -- Frame 2: landing sparkle
        if frame == 2 then
            img:drawPixel(2, 14 + childShrink, SPARKLE)
            img:drawPixel(13, 14 + childShrink, SPARKLE)
        end
    elseif mode == "medic" then
        -- Frame 0: beak wide open
        if frame == 0 then
            img:drawPixel(7, 6, BEAK)
            img:drawPixel(8, 6, BEAK)
            img:drawPixel(9, 6, BEAK)
        end
        -- Frame 2: small sparkle (healed feel)
        if frame == 2 then
            img:drawPixel(14, 2, SPARKLE)
        end
    elseif mode == "poop_act" then
        -- Frame 1: effort marks above head
        if frame == 1 then
            img:drawPixel(7, 0, WARN)
            img:drawPixel(8, 0, WARN)
        end
    elseif mode == "clean_act" then
        -- Frame 2: sparkle (clean!)
        if frame == 2 then
            img:drawPixel(1, 2, SPARKLE)
            img:drawPixel(14, 3, SPARKLE)
            img:drawPixel(3, 4, SPARKLE)
            img:drawPixel(12, 2, SPARKLE)
        end
    end
    -- "hide", "bounce", "sit" have no extra overlay — they're pure positional shifts
end

------------------------------------------------------------------
-- Egg + departed drawers
------------------------------------------------------------------
local function renderEgg(img, frame)
    local wiggle = (math.floor(frame / 2) % 2 == 0) and 0 or 1
    for row = 1, SIDE do
        for col = 1, SIDE do
            local cell = EGG[row][col]
            if cell ~= 0 then
                local x = col - 1 + wiggle
                local y = row - 1
                if inBounds(x, y) then
                    if cell == 1 then
                        img:drawPixel(x, y, SHELL)
                    elseif cell == 2 then
                        img:drawPixel(x, y, SHELL_OUT)
                    end
                end
            end
        end
    end
    img:drawPixel(6 + wiggle, 5, SPECKLE)
    img:drawPixel(9 + wiggle, 8, SPECKLE)
    img:drawPixel(5 + wiggle, 10, SPECKLE)
end

local function renderDeparted(img, frame)
    local bright = (math.floor(frame / 2) % 2 == 0)
    local bodyA = bright and 128 or 77
    local outA = bright and 89 or 55
    local bodyC = Color{ r = 217, g = 204, b = 179, a = bodyA }
    local outC  = Color{ r = 255, g = 255, b = 255, a = outA }
    for row = 1, SIDE do
        for col = 1, SIDE do
            local cell = GHOST[row][col]
            if cell == 1 then
                img:drawPixel(col - 1, row - 1, bodyC)
            elseif cell == 2 then
                img:drawPixel(col - 1, row - 1, outC)
            end
        end
    end
end

------------------------------------------------------------------
-- Tag catalog. New convention:
--   chick_egg_idle
--   chick_child_<mode>
--   chick_<personality>_<stage>_<mode>
--   chick_<personality>_<stage>_<micro>
--   chick_departed_idle
------------------------------------------------------------------
local SEQUENCES = {}
local function push(name, drawer, n)
    SEQUENCES[#SEQUENCES + 1] = { name = name, drawer = drawer, count = n }
end

push("chick_egg_idle", function(img, f) renderEgg(img, f) end, 4)

local MODE_FRAMES = {
    idle     = 4,
    hungry   = 4,
    happy    = 4,
    sick     = 3,
    sleeping = 2,
    curious  = 4,
    angry    = 4,
    -- micro-actions
    lick     = 3,
    lookaway = 3,
    hide     = 3,
    huff     = 3,
    yawn     = 3,
    bounce   = 3,
    -- ambient behaviors
    walk     = 4,
    peck     = 3,
    flap     = 3,
    dance    = 4,
    stretch  = 3,
    sit      = 2,
    -- action feedback
    eat      = 3,
    play_act = 3,
    medic    = 3,
    poop_act = 3,
    clean_act = 3,
}

-- Child uses cheerful expression (personality not fixed yet).
-- Child gets base modes + ambient + action feedback (but not personality micro-actions)
local CHILD_MODES = { "idle", "hungry", "happy", "sick", "sleeping", "curious",
                      "walk", "peck", "flap", "dance", "stretch", "sit",
                      "eat", "play_act", "medic", "poop_act", "clean_act" }
for _, mode in ipairs(CHILD_MODES) do
    push("chick_child_" .. mode, function(img, f)
        renderChick(img, "cheerful", "child", mode, f)
    end, MODE_FRAMES[mode])
end

local PERSONALITY_NAMES = { "cheerful", "shy", "aloof", "gluttonous", "lazy", "grumpy" }
local BASE_MODES = { "idle", "hungry", "happy", "sick", "sleeping", "curious" }
local AMBIENT_MODES = { "walk", "peck", "flap", "dance", "stretch", "sit" }
local ACTION_MODES = { "eat", "play_act", "medic", "poop_act", "clean_act" }

-- Per-personality micro-action assignments
local MICRO_ACTIONS = {
    cheerful   = { "bounce" },
    shy        = { "hide" },
    aloof      = { "lookaway" },
    gluttonous = { "lick" },
    lazy       = { "yawn" },
    grumpy     = { "huff" },
}

for _, personality in ipairs(PERSONALITY_NAMES) do
    for _, stage in ipairs({ "adult", "elder" }) do
        -- Standard state modes
        for _, mode in ipairs(BASE_MODES) do
            local tagName = "chick_" .. personality .. "_" .. stage .. "_" .. mode
            push(tagName, function(img, f)
                renderChick(img, personality, stage, mode, f)
            end, MODE_FRAMES[mode])
        end
        -- Grumpy-only angry mode
        if personality == "grumpy" then
            push("chick_grumpy_" .. stage .. "_angry", function(img, f)
                renderChick(img, "grumpy", stage, "angry", f)
            end, MODE_FRAMES.angry)
        end
        -- Ambient behaviors (all personalities)
        for _, mode in ipairs(AMBIENT_MODES) do
            local tagName = "chick_" .. personality .. "_" .. stage .. "_" .. mode
            push(tagName, function(img, f)
                renderChick(img, personality, stage, mode, f)
            end, MODE_FRAMES[mode])
        end
        -- Action feedback (all personalities)
        for _, mode in ipairs(ACTION_MODES) do
            local tagName = "chick_" .. personality .. "_" .. stage .. "_" .. mode
            push(tagName, function(img, f)
                renderChick(img, personality, stage, mode, f)
            end, MODE_FRAMES[mode])
        end
        -- Personality micro-actions
        local micros = MICRO_ACTIONS[personality] or {}
        for _, micro in ipairs(micros) do
            local tagName = "chick_" .. personality .. "_" .. stage .. "_" .. micro
            push(tagName, function(img, f)
                renderChick(img, personality, stage, micro, f)
            end, MODE_FRAMES[micro])
        end
    end
end

push("chick_departed_idle", function(img, f) renderDeparted(img, f) end, 2)

------------------------------------------------------------------
-- Build the sprite document.
------------------------------------------------------------------
local spr = Sprite(SIDE, SIDE, ColorMode.RGB)
spr.filename = OUTPUT

local layer = spr.layers[1]
local totalFrames = 0
for _, seq in ipairs(SEQUENCES) do
    totalFrames = totalFrames + seq.count
end

while #spr.frames < totalFrames do
    spr:newEmptyFrame()
end

local frameIdx = 1
local tagBoundaries = {}
for _, seq in ipairs(SEQUENCES) do
    local from = frameIdx
    for local_f = 0, seq.count - 1 do
        local img = Image(SIDE, SIDE, ColorMode.RGB)
        seq.drawer(img, local_f)
        local existing = layer:cel(frameIdx)
        if existing then
            spr:deleteCel(existing)
        end
        spr:newCel(layer, frameIdx, img, Point(0, 0))
        frameIdx = frameIdx + 1
    end
    local to = frameIdx - 1
    tagBoundaries[#tagBoundaries + 1] = { name = seq.name, from = from, to = to }
end

for _, tb in ipairs(tagBoundaries) do
    local tag = spr:newTag(tb.from, tb.to)
    tag.name = tb.name
end

spr:saveAs(OUTPUT)
print(string.format("Wrote %s: %d frames, %d tags", OUTPUT, totalFrames, #tagBoundaries))
