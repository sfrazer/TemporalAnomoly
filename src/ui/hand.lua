local Tooltip = require("src.ui.tooltip")
local Shapes  = require("src.ui.shapes")

local M = {}

local CARD_W     = 100
local CARD_H     = 62
local GAP        = 8
local VISIBLE_MAX = 10  -- max cards shown at once; arrows appear when hand exceeds this
local ARROW_W    = 32
local ARROW_PAD  = 6

local PERIOD_COLOR = {
    prehistory = {0.25, 0.52, 0.95},
    industrial = {0.90, 0.78, 0.10},
    modern     = {0.55, 0.55, 0.60},
    far_future = {0.90, 0.20, 0.20},
}

local EVENT_COLOR = {0.40, 0.28, 0.70}
local FLUX_COLOR  = {0.80, 0.35, 0.10}

-- Sort state (module-level; persisted via profile.handSortMode)
local handSortMode    = "insertion"
local handScrollOffset = 0

local SORT_CYCLE   = {"insertion", "color", "period", "type"}
local COLOR_ORDER  = {blue = 1, yellow = 2, black = 3, red = 4}
local PERIOD_ORDER = {prehistory = 1, industrial = 2, modern = 3, far_future = 4}
local TYPE_ORDER   = {city = 1, event = 2, flux = 3}

local function getSortedIndices(hand, mode)
    local idx = {}
    for i = 1, #hand do idx[i] = i end
    if mode == "color" then
        table.sort(idx, function(a, b)
            return (COLOR_ORDER[hand[a].color] or 99) < (COLOR_ORDER[hand[b].color] or 99)
        end)
    elseif mode == "period" then
        table.sort(idx, function(a, b)
            return (PERIOD_ORDER[hand[a].period] or 99) < (PERIOD_ORDER[hand[b].period] or 99)
        end)
    elseif mode == "type" then
        table.sort(idx, function(a, b)
            return (TYPE_ORDER[hand[a].type] or 99) < (TYPE_ORDER[hand[b].type] or 99)
        end)
    end
    return idx
end

local function getDisplaySlice(hand)
    local sorted = getSortedIndices(hand, handSortMode)
    local n      = #sorted
    local needsScroll = n > VISIBLE_MAX
    local maxOffset   = math.max(0, n - VISIBLE_MAX)
    handScrollOffset  = math.max(0, math.min(handScrollOffset, maxOffset))
    local startIdx = needsScroll and (handScrollOffset + 1) or 1
    local endIdx   = math.min(startIdx + VISIBLE_MAX - 1, n)
    local display  = {}
    for i = startIdx, endIdx do
        display[#display + 1] = sorted[i]
    end
    return display, needsScroll, maxOffset
end

local function cardStartX(display, needsScroll)
    local visN  = #display
    local areaX = needsScroll and (ARROW_PAD + ARROW_W + ARROW_PAD) or 0
    local areaW = needsScroll and (1280 - 2 * (ARROW_PAD + ARROW_W + ARROW_PAD)) or 1280
    local total = visN * CARD_W + math.max(0, visN - 1) * GAP
    return areaX + (areaW - total) / 2
end

local function cardColor(card)
    if card.type == "event" then return EVENT_COLOR end
    if card.type == "flux"  then return FLUX_COLOR  end
    return PERIOD_COLOR[card.period] or {0.4, 0.4, 0.4}
end

function M.render(state, handY, selected)
    local display, needsScroll, maxOffset = getDisplaySlice(state.hand)
    local startX = cardStartX(display, needsScroll)
    local font   = love.graphics.getFont()

    for i, origIdx in ipairs(display) do
        local card = state.hand[origIdx]
        local x    = startX + (i - 1) * (CARD_W + GAP)
        local pc   = cardColor(card)
        local sel  = (selected == origIdx)

        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", x+2, handY+2, CARD_W, CARD_H, 5)

        love.graphics.setColor(0.13, 0.15, 0.19)
        love.graphics.rectangle("fill", x, handY, CARD_W, CARD_H, 5)

        love.graphics.setColor(pc[1], pc[2], pc[3])
        love.graphics.rectangle("fill", x, handY, CARD_W, 5, 5)
        love.graphics.rectangle("fill", x, handY, CARD_W, 3)

        if sel then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(pc[1]*0.7, pc[2]*0.7, pc[3]*0.7, 0.8)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", x, handY, CARD_W, CARD_H, 5)

        love.graphics.setColor(0.95, 0.95, 0.95)
        if card.type == "city" then
            love.graphics.printf(card.name:gsub(" %(.*%)", ""), x+5, handY+10, CARD_W-10, "center")
            love.graphics.setColor(pc[1], pc[2], pc[3], 0.85)
            local period = card.name:match("%((.-)%)") or ""
            love.graphics.printf(period, x+5, handY+38, CARD_W-10, "center")
            love.graphics.setColor(0.05, 0.06, 0.09, 0.85)
            Shapes.draw(card.color, x + CARD_W - 8, handY + 3, 7)
        elseif card.type == "event" then
            love.graphics.setColor(0.85, 0.7, 1)
            love.graphics.printf(card.name, x+5, handY+10, CARD_W-10, "center")
        elseif card.type == "flux" then
            love.graphics.setColor(1, 0.6, 0.2)
            love.graphics.printf("Flux", x+5, handY+24, CARD_W-10, "center")
        end

        local tip
        if card.type == "city" then
            tip = card.name .. "\nDiscard to Teleport here, or to Build an Outpost in " ..
                  card.name:match("^([^%(]+)"):gsub("%s+$", "") .. "."
        elseif card.type == "event" then
            tip = card.name .. "\n" .. (card.description or "")
        elseif card.type == "flux" then
            tip = "Chronological Flux\nResolves immediately when drawn: advance Instability Level, " ..
                  "place 3 cubes on the bottom threat card, reshuffle discards onto the deck."
        end
        if tip then Tooltip.push(x, handY, CARD_W, CARD_H, tip) end
    end

    -- Scroll arrows (only when hand overflows)
    if needsScroll then
        local leftOn  = handScrollOffset > 0
        local rightOn = handScrollOffset < maxOffset
        local arrowY  = handY

        love.graphics.setColor(leftOn and 0.30 or 0.14, leftOn and 0.35 or 0.16, leftOn and 0.45 or 0.20)
        love.graphics.rectangle("fill", ARROW_PAD, arrowY, ARROW_W, CARD_H, 4)
        love.graphics.setColor(1, 1, 1, leftOn and 0.85 or 0.25)
        love.graphics.printf("<", ARROW_PAD, arrowY + (CARD_H - font:getHeight()) / 2, ARROW_W, "center")

        local rx = 1280 - ARROW_PAD - ARROW_W
        love.graphics.setColor(rightOn and 0.30 or 0.14, rightOn and 0.35 or 0.16, rightOn and 0.45 or 0.20)
        love.graphics.rectangle("fill", rx, arrowY, ARROW_W, CARD_H, 4)
        love.graphics.setColor(1, 1, 1, rightOn and 0.85 or 0.25)
        love.graphics.printf(">", rx, arrowY + (CARD_H - font:getHeight()) / 2, ARROW_W, "center")
    end

    -- Sort mode indicator (bottom-right of hand strip)
    local sortLabel = "Sort: " .. handSortMode
    love.graphics.setColor(0.42, 0.48, 0.62, 0.70)
    love.graphics.printf(sortLabel .. "  ", 0, handY + CARD_H + 3, 1280, "right")
end

-- Returns original hand index (1-based) or nil.
function M.hitCard(vx, vy, state, handY)
    local display, needsScroll = getDisplaySlice(state.hand)
    local startX = cardStartX(display, needsScroll)
    for i, origIdx in ipairs(display) do
        local x = startX + (i - 1) * (CARD_W + GAP)
        if vx >= x and vx <= x + CARD_W and vy >= handY and vy <= handY + CARD_H then
            return origIdx
        end
    end
    return nil
end

-- Returns "scroll_left", "scroll_right", "sort", or nil.
function M.hitControl(vx, vy, handY, n)
    local needsScroll = n > VISIBLE_MAX
    if needsScroll then
        if vx >= ARROW_PAD and vx <= ARROW_PAD + ARROW_W and vy >= handY and vy <= handY + CARD_H then
            return "scroll_left"
        end
        local rx = 1280 - ARROW_PAD - ARROW_W
        if vx >= rx and vx <= rx + ARROW_W and vy >= handY and vy <= handY + CARD_H then
            return "scroll_right"
        end
    end
    -- Sort label hit area (bottom-right strip below cards)
    local sortY = handY + CARD_H + 2
    if vy >= sortY and vy <= sortY + 14 and vx >= 900 then
        return "sort"
    end
    return nil
end

function M.cycleSortMode()
    for i, mode in ipairs(SORT_CYCLE) do
        if mode == handSortMode then
            handSortMode      = SORT_CYCLE[i % #SORT_CYCLE + 1]
            handScrollOffset  = 0
            return handSortMode
        end
    end
    handSortMode = "insertion"
    return handSortMode
end

function M.setSortMode(mode)
    handSortMode     = mode or "insertion"
    handScrollOffset = 0
end

function M.getSortMode()
    return handSortMode
end

function M.scrollLeft()
    handScrollOffset = math.max(0, handScrollOffset - 1)
end

function M.scrollRight(n)
    local maxOffset  = math.max(0, n - VISIBLE_MAX)
    handScrollOffset = math.min(maxOffset, handScrollOffset + 1)
end

return M
