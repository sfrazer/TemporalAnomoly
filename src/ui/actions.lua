local M = {}

local BASE_BUTTONS = {
    {id = "travel",      label = "Travel"},
    {id = "teleport",    label = "Teleport"},
    {id = "teleport_alt",label = "Teleport Alt"},
    {id = "build",       label = "Build Outpost"},
    {id = "clear",       label = "Clear Incident"},
    {id = "resolve",     label = "Resolve Anomaly"},
    {id = "end_turn",    label = "End Turn"},
}

local BTN_H   = 38
local BTN_PAD = 10
local ROW_PAD = 8

-- Returns the button list for the current game state. The Coordinator gets an
-- extra free-move button that disappears once used for the turn.
local function getButtons(gs)
    local btns = {}
    for _, b in ipairs(BASE_BUTTONS) do btns[#btns + 1] = b end
    if gs and gs.role == "coordinator" and not gs.coordinatorMoveUsed then
        -- Insert before "End Turn"
        table.insert(btns, #btns, {id = "coordinator_move", label = "Coord. Move"})
    end
    return btns
end

function M.render(actY, actH, activeId, gs)
    local buttons = getButtons(gs)
    local n       = #buttons

    -- Background bar
    love.graphics.setColor(0.10, 0.12, 0.16)
    love.graphics.rectangle("fill", 0, actY, 1280, actH)
    love.graphics.setColor(0.25, 0.28, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, actY, 1280, actY)

    local totalW = 1280 - BTN_PAD * (n + 1)
    local btnW   = totalW / n
    local y      = actY + ROW_PAD

    for i, btn in ipairs(buttons) do
        local x      = BTN_PAD + (i - 1) * (btnW + BTN_PAD)
        local active = (btn.id == activeId)

        -- Button fill
        if active then
            love.graphics.setColor(0.22, 0.50, 0.80)
        elseif btn.id == "end_turn" then
            love.graphics.setColor(0.22, 0.45, 0.22)
        elseif btn.id == "coordinator_move" then
            love.graphics.setColor(0.35, 0.18, 0.55)
        else
            love.graphics.setColor(0.20, 0.24, 0.30)
        end
        love.graphics.rectangle("fill", x, y, btnW, BTN_H, 4)

        -- Border
        love.graphics.setColor(active and 0.55 or 0.35, active and 0.75 or 0.40,
                                active and 1.0  or 0.50, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, btnW, BTN_H, 4)

        -- Label
        love.graphics.setColor(1, 1, 1, active and 1 or 0.85)
        local font = love.graphics.getFont()
        local tw   = font:getWidth(btn.label)
        love.graphics.print(btn.label, x + (btnW - tw)/2, y + (BTN_H - font:getHeight())/2)
    end
end

-- Returns button id or nil
function M.hit(vx, vy, actY, actH, gs)
    if vy < actY or vy > actY + actH then return nil end
    local buttons = getButtons(gs)
    local n       = #buttons
    local totalW  = 1280 - BTN_PAD * (n + 1)
    local btnW    = totalW / n
    local y       = actY + ROW_PAD
    for i, btn in ipairs(buttons) do
        local x = BTN_PAD + (i - 1) * (btnW + BTN_PAD)
        if vx >= x and vx <= x + btnW and vy >= y and vy <= y + BTN_H then
            return btn.id
        end
    end
    return nil
end

return M
