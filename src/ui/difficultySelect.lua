local M = {}

local VW, VH = 1280, 720

local DIFFICULTIES = {
    {
        id       = "introductory",
        name     = "Introductory",
        flux     = 4,
        resolves = "2 of 4",
        extra    = "",
        desc     = "Best for your first run.\nGentle curve, fewer crises.",
    },
    {
        id       = "standard",
        name     = "Standard",
        flux     = 5,
        resolves = "3 of 4",
        extra    = "",
        desc     = "The intended experience.\nBalanced threat and opportunity.",
    },
    {
        id       = "heroic",
        name     = "Heroic",
        flux     = 6,
        resolves = "4 of 4",
        extra    = "Alt win: REPAIR any 2",
        desc     = "Demanding pace. All anomalies\nmust be resolved — or repair 2.",
    },
    {
        id       = "legendary",
        name     = "Legendary",
        flux     = 7,
        resolves = "4 of 4",
        extra    = "Priority City — instant loss",
        desc     = "Unforgiving. One city is critical.\nIt cannot fall in any period.",
    },
}

local ACCENT = {
    introductory = {0.30, 0.65, 0.30},
    standard     = {0.30, 0.55, 0.90},
    heroic       = {0.80, 0.55, 0.10},
    legendary    = {0.80, 0.20, 0.20},
}

local CARD_W   = 256
local CARD_H   = 190
local CARD_GAP = 18
local CARD_Y   = 190

local function cardX(i)
    local totalW = 4 * CARD_W + 3 * CARD_GAP
    local startX = (VW - totalW) / 2
    return startX + (i - 1) * (CARD_W + CARD_GAP)
end

function M.render()
    love.graphics.setColor(0.04, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, VW, VH)

    love.graphics.setColor(0.75, 0.80, 0.95)
    love.graphics.printf("Select Difficulty", 0, 28, VW, "center")

    for i, d in ipairs(DIFFICULTIES) do
        local x  = cardX(i)
        local ac = ACCENT[d.id]

        -- Card body
        love.graphics.setColor(0.10, 0.12, 0.16)
        love.graphics.rectangle("fill", x, CARD_Y, CARD_W, CARD_H, 6)

        -- Accent top bar
        love.graphics.setColor(ac[1], ac[2], ac[3], 0.80)
        love.graphics.rectangle("fill", x, CARD_Y, CARD_W, 6, 6)
        love.graphics.rectangle("fill", x, CARD_Y, CARD_W, 3)

        -- Border
        love.graphics.setColor(ac[1], ac[2], ac[3], 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, CARD_Y, CARD_W, CARD_H, 6)

        -- Name
        love.graphics.setColor(0.92, 0.92, 0.96)
        love.graphics.printf(d.name, x + 8, CARD_Y + 16, CARD_W - 16, "center")

        -- Description
        love.graphics.setColor(0.55, 0.58, 0.68)
        love.graphics.printf(d.desc, x + 10, CARD_Y + 50, CARD_W - 20, "center")

        -- Stats
        love.graphics.setColor(0.70, 0.72, 0.82)
        love.graphics.printf("Flux cards: " .. d.flux, x + 8, CARD_Y + 130, CARD_W - 16, "center")
        love.graphics.printf("RESOLVE: " .. d.resolves, x + 8, CARD_Y + 148, CARD_W - 16, "center")

        -- Extra rule
        if d.extra ~= "" then
            love.graphics.setColor(ac[1], ac[2], ac[3])
            love.graphics.printf(d.extra, x + 8, CARD_Y + 166, CARD_W - 16, "center")
        end
    end
end

-- Returns difficulty id if a card was clicked, nil otherwise.
function M.hit(vx, vy)
    if vy < CARD_Y or vy > CARD_Y + CARD_H then return nil end
    for i, d in ipairs(DIFFICULTIES) do
        local x = cardX(i)
        if vx >= x and vx <= x + CARD_W then
            return d.id
        end
    end
    return nil
end

return M
