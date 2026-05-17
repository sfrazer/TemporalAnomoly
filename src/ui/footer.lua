local unpack = table.unpack or unpack  -- LuaJIT (Love2D) vs Lua 5.2+
local util = require("src.util")

local M = {}

local WARN_COLOR   = {0.95, 0.20, 0.20}
local NORMAL_COLOR = {0.75, 0.78, 0.82}
local LABEL_COLOR  = {0.45, 0.50, 0.58}

local COLOR_ACCENT = {
    blue   = {0.30, 0.55, 0.95},
    yellow = {0.90, 0.82, 0.10},
    black  = {0.65, 0.65, 0.70},
    red    = {0.90, 0.20, 0.20},
}

function M.render(state, footerY, footerH)
    -- Background
    love.graphics.setColor(0.06, 0.07, 0.09)
    love.graphics.rectangle("fill", 0, footerY, 1280, footerH)
    love.graphics.setColor(0.22, 0.25, 0.30)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, footerY, 1280, footerY)

    local x  = 16
    local y  = footerY + (footerH - love.graphics.getFont():getHeight()) / 2
    local sp = 10

    -- Deck count
    local deckN = #state.playerDeck
    local deckWarn = deckN <= 5
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Deck:", x, y)
    x = x + love.graphics.getFont():getWidth("Deck:") + sp
    love.graphics.setColor(unpack(deckWarn and WARN_COLOR or NORMAL_COLOR))
    love.graphics.print(tostring(deckN), x, y)
    x = x + love.graphics.getFont():getWidth(tostring(deckN)) + sp*3

    -- Cube supplies
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Supply:", x, y)
    x = x + love.graphics.getFont():getWidth("Supply:") + sp

    for _, color in ipairs({"blue","yellow","black","red"}) do
        local supply = util.cubeSupply(state, color)
        local warn   = supply <= 4
        love.graphics.setColor(unpack(COLOR_ACCENT[color]))
        love.graphics.print(color:sub(1,1):upper() .. ":", x, y)
        x = x + love.graphics.getFont():getWidth(color:sub(1,1):upper() .. ":") + 3
        love.graphics.setColor(unpack(warn and WARN_COLOR or NORMAL_COLOR))
        love.graphics.print(tostring(supply), x, y)
        x = x + love.graphics.getFont():getWidth(tostring(supply)) + sp*2
    end

    x = x + sp

    -- Instability level
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Instability:", x, y)
    x = x + love.graphics.getFont():getWidth("Instability:") + sp
    love.graphics.setColor(unpack(NORMAL_COLOR))
    love.graphics.print(tostring(util.instabilityLevel(state)), x, y)
    x = x + love.graphics.getFont():getWidth(tostring(util.instabilityLevel(state))) + sp*3

    -- Temporal Explosions
    local explosions = state.explosionCount
    local explWarn   = explosions >= 6
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Explosions:", x, y)
    x = x + love.graphics.getFont():getWidth("Explosions:") + sp
    love.graphics.setColor(unpack(explWarn and WARN_COLOR or NORMAL_COLOR))
    love.graphics.print(tostring(explosions) .. "/8", x, y)
    x = x + love.graphics.getFont():getWidth(tostring(explosions) .. "/8") + sp*3

    -- Resolved anomalies
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Resolved:", x, y)
    x = x + love.graphics.getFont():getWidth("Resolved:") + sp
    for _, color in ipairs({"blue","yellow","black","red"}) do
        local ac = COLOR_ACCENT[color]
        if state.repaired[color] then
            love.graphics.setColor(ac[1], ac[2], ac[3])
            love.graphics.print("★", x, y)
        elseif state.resolved[color] then
            love.graphics.setColor(ac[1], ac[2], ac[3], 0.7)
            love.graphics.print("◆", x, y)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.print("◇", x, y)
        end
        x = x + 18
    end

    -- Location
    love.graphics.setColor(unpack(LABEL_COLOR))
    local loc = "  |  " .. state.currentCity:gsub("_", " "):gsub("(%a)([%a]*)", function(a,b) return a:upper()..b end)
               .. " / " .. (state.currentPeriod:gsub("_", " "))
    love.graphics.print(loc, x, y)
end

return M
