local unpack  = table.unpack or unpack  -- LuaJIT (Love2D) vs Lua 5.2+
local util    = require("src.util")
local Tooltip = require("src.ui.tooltip")
local Shapes  = require("src.ui.shapes")

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

-- Build role lookup at module load time
local ROLE_BY_ID = {}
do
    local ok, roles = pcall(require, "data.roles")
    if ok then
        for _, r in ipairs(roles) do ROLE_BY_ID[r.id] = r end
    end
end

-- Chip layout constants
local CHIP_H     = 20
local CHIP_PAD_X = 7
local CHIP_GAP   = 5

-- Renders a single chip (right edge at rx), returns new rx.
local function renderChip(font, rx, chipY, label, r, g, b, tip)
    local tw = font:getWidth(label)
    local cw = tw + CHIP_PAD_X * 2
    local cx = rx - cw
    love.graphics.setColor(r, g, b, 0.18)
    love.graphics.rectangle("fill", cx, chipY, cw, CHIP_H, 3)
    love.graphics.setColor(r, g, b, 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cx, chipY, cw, CHIP_H, 3)
    love.graphics.setColor(r, g, b, 0.90)
    love.graphics.print(label, cx + CHIP_PAD_X, chipY + (CHIP_H - font:getHeight()) / 2)
    if tip then Tooltip.push(cx, chipY, cw, CHIP_H, tip) end
    return cx - CHIP_GAP
end

function M.render(state, footerY, footerH)
    -- Background
    love.graphics.setColor(0.06, 0.07, 0.09)
    love.graphics.rectangle("fill", 0, footerY, 1280, footerH)
    love.graphics.setColor(0.22, 0.25, 0.30)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, footerY, 1280, footerY)

    local font = love.graphics.getFont()
    local x    = 16
    local y    = footerY + (footerH - font:getHeight()) / 2
    local sp   = 10
    local sx   -- tooltip start-x for each stat group

    -- Deck count
    local deckN = #state.playerDeck
    local deckWarn = deckN <= 5
    sx = x
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Deck:", x, y)
    x = x + font:getWidth("Deck:") + sp
    love.graphics.setColor(unpack(deckWarn and WARN_COLOR or NORMAL_COLOR))
    love.graphics.print(tostring(deckN), x, y)
    x = x + font:getWidth(tostring(deckN)) + sp*3
    Tooltip.push(sx, footerY, x - sx, footerH,
        "Cards remaining in your player deck.\nIf you must draw but the deck is empty, you lose immediately.\nTurns red at 5 cards.")

    -- Cube supplies
    sx = x
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Supply:", x, y)
    x = x + font:getWidth("Supply:") + sp

    for _, color in ipairs({"blue","yellow","black","red"}) do
        local supply = util.cubeSupply(state, color)
        local warn   = supply <= 4
        local csx    = x
        local midY   = y + font:getHeight() / 2
        love.graphics.setColor(unpack(COLOR_ACCENT[color]))
        Shapes.draw(color, x + 5, midY, 8)
        x = x + 10 + 2
        love.graphics.print(Shapes.LABEL[color] .. ":", x, y)
        x = x + font:getWidth(Shapes.LABEL[color] .. ":") + 3
        love.graphics.setColor(unpack(warn and WARN_COLOR or NORMAL_COLOR))
        love.graphics.print(tostring(supply), x, y)
        x = x + font:getWidth(tostring(supply)) + sp*2
        Tooltip.push(csx, footerY, x - csx, footerH,
            color:sub(1,1):upper() .. color:sub(2) .. " anomaly cube supply.\nIf this reaches 0, you lose immediately.\nTurns red at 4 cubes.")
    end

    x = x + sp

    -- Instability level
    sx = x
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Instability:", x, y)
    x = x + font:getWidth("Instability:") + sp
    love.graphics.setColor(unpack(NORMAL_COLOR))
    love.graphics.print(tostring(util.instabilityLevel(state)), x, y)
    x = x + font:getWidth(tostring(util.instabilityLevel(state))) + sp*3
    do
        local SCHEDULE = {2, 2, 2, 3, 3, 4, 4}
        local idx  = state.instabilityIndex or 1
        local segs = {
            {t = "Threat cards drawn each Instability Phase.\nAdvances after each Chronological Flux.\nSchedule:  "},
        }
        for i, v in ipairs(SCHEDULE) do
            if i == idx then
                segs[#segs+1] = {t = tostring(v), r = 0.92, g = 0.22, b = 0.22, bold = true}
            else
                segs[#segs+1] = {t = tostring(v), r = 0.50, g = 0.53, b = 0.62}
            end
            if i < #SCHEDULE then segs[#segs+1] = {t = "  "} end
        end
        Tooltip.push(sx, footerY, x - sx, footerH, segs)
    end

    -- Temporal Explosions
    local explosions = state.explosionCount
    local explWarn   = explosions >= 6
    sx = x
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Explosions:", x, y)
    x = x + font:getWidth("Explosions:") + sp
    love.graphics.setColor(unpack(explWarn and WARN_COLOR or NORMAL_COLOR))
    love.graphics.print(tostring(explosions) .. "/8", x, y)
    x = x + font:getWidth(tostring(explosions) .. "/8") + sp*3
    Tooltip.push(sx, footerY, x - sx, footerH,
        "Temporal Explosions this run.\n8 explosions is an immediate loss.\nTurns red at 6.")

    -- Resolved / Repaired anomaly status
    sx = x
    love.graphics.setColor(unpack(LABEL_COLOR))
    love.graphics.print("Resolved:", x, y)
    x = x + font:getWidth("Resolved:") + sp
    for _, color in ipairs({"blue","yellow","black","red"}) do
        local ac = COLOR_ACCENT[color]
        if state.repaired[color] then
            -- Thick X for REPAIRED (0 cubes remain everywhere)
            love.graphics.setColor(ac[1], ac[2], ac[3])
            love.graphics.setLineWidth(2.5)
            local cx2 = x + 7
            local cy2 = y + font:getHeight() / 2
            local r   = 5
            love.graphics.line(cx2 - r, cy2 - r, cx2 + r, cy2 + r)
            love.graphics.line(cx2 + r, cy2 - r, cx2 - r, cy2 + r)
            x = x + 18
        elseif state.resolved[color] then
            love.graphics.setColor(ac[1], ac[2], ac[3], 0.7)
            love.graphics.print("◆", x, y)
            x = x + 18
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.print("◇", x, y)
            x = x + 18
        end
    end
    Tooltip.push(sx, footerY, x - sx, footerH,
        "Anomaly status per color.\n◇ = Active   ◆ = Resolved   X = Repaired\nRepaired means 0 cubes remain — future threat cards of that color have no effect.")

    -- -----------------------------------------------------------------------
    -- Right-aligned chips: role + active effects
    -- -----------------------------------------------------------------------
    local chipY = footerY + (footerH - CHIP_H) / 2
    local rx    = 1272

    -- Role chip (rightmost)
    if state.role then
        local rd = ROLE_BY_ID[state.role]
        if rd then
            rx = renderChip(font, rx, chipY,
                rd.name,
                rd.color[1], rd.color[2], rd.color[3],
                rd.description)
        end
    end

    -- Active-effect chips (left of role chip)
    if state.role == "coordinator" and not state.coordinatorMoveUsed then
        rx = renderChip(font, rx, chipY, "Coord. Move",
            0.65, 0.30, 0.90,
            "Coordinator: free move to any Temporal Outpost city available this turn.")
    end
    if state.role == "failsafe_designer" and not state.failsafeDesignerUsed then
        rx = renderChip(font, rx, chipY, "Retrieve",
            0.12, 0.60, 0.62,
            "Failsafe Designer: can retrieve 1 event card from discard this run.")
    end
    if state.sealedCity then
        local cityName = state.sealedCity:gsub("_", " ")
                            :gsub("(%a)([%a]*)", function(a, b) return a:upper() .. b end)
        rx = renderChip(font, rx, chipY, "Sealed: " .. cityName,
            0.55, 0.25, 0.80,
            cityName .. " is sealed — no cube placements until next Instability Phase.")
    end
    if state.skipNextInstability then
        rx = renderChip(font, rx, chipY, "Barrier",    -- luacheck: ignore (rx unused after last chip)
            0.20, 0.70, 0.65,
            "Paradox Barrier active — next Instability Phase will be skipped.")
    end
end

return M
