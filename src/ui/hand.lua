local M = {}

local CARD_W = 100
local CARD_H = 62
local GAP    = 8

local PERIOD_COLOR = {
    prehistory = {0.25, 0.52, 0.95},
    industrial = {0.90, 0.78, 0.10},
    modern     = {0.55, 0.55, 0.60},
    far_future = {0.90, 0.20, 0.20},
}

local EVENT_COLOR = {0.40, 0.28, 0.70}
local FLUX_COLOR  = {0.80, 0.35, 0.10}

local function cardColor(card)
    if card.type == "event" then return EVENT_COLOR end
    if card.type == "flux"  then return FLUX_COLOR  end
    return PERIOD_COLOR[card.period] or {0.4, 0.4, 0.4}
end

function M.render(state, handY, selected)
    local n     = #state.hand
    local total = n * CARD_W + math.max(0, n-1) * GAP
    local startX = (1280 - total) / 2

    for i, card in ipairs(state.hand) do
        local x  = startX + (i-1) * (CARD_W + GAP)
        local pc = cardColor(card)
        local sel = (selected == i)

        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", x+2, handY+2, CARD_W, CARD_H, 5)

        -- Card body
        love.graphics.setColor(0.13, 0.15, 0.19)
        love.graphics.rectangle("fill", x, handY, CARD_W, CARD_H, 5)

        -- Color accent top bar
        love.graphics.setColor(pc[1], pc[2], pc[3])
        love.graphics.rectangle("fill", x, handY, CARD_W, 5, 5)
        love.graphics.rectangle("fill", x, handY, CARD_W, 3)  -- square bottom edge

        -- Border
        if sel then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(pc[1]*0.7, pc[2]*0.7, pc[3]*0.7, 0.8)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", x, handY, CARD_W, CARD_H, 5)

        -- Card text
        love.graphics.setColor(0.95, 0.95, 0.95)
        if card.type == "city" then
            local font = love.graphics.getFont()
            -- Wrap city name if needed
            love.graphics.printf(card.name:gsub(" %(.*%)", ""), x+5, handY+10, CARD_W-10, "center")
            love.graphics.setColor(pc[1], pc[2], pc[3], 0.85)
            local period = card.name:match("%((.-)%)") or ""
            love.graphics.printf(period, x+5, handY+38, CARD_W-10, "center")
        elseif card.type == "event" then
            love.graphics.setColor(0.85, 0.7, 1)
            love.graphics.printf(card.name, x+5, handY+10, CARD_W-10, "center")
        elseif card.type == "flux" then
            love.graphics.setColor(1, 0.6, 0.2)
            love.graphics.printf("Flux", x+5, handY+24, CARD_W-10, "center")
        end
    end
end

-- Returns card index (1-based) or nil
function M.hitCard(vx, vy, state, handY)
    local n     = #state.hand
    local total = n * CARD_W + math.max(0, n-1) * GAP
    local startX = (1280 - total) / 2
    for i = 1, n do
        local x = startX + (i-1) * (CARD_W + GAP)
        if vx >= x and vx <= x+CARD_W and vy >= handY and vy <= handY+CARD_H then
            return i
        end
    end
    return nil
end

return M
