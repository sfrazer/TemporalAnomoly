local M = {}

local PANEL_X = 280
local PANEL_Y = 80
local PANEL_W = 720
local PANEL_H = 560

local ROW_X   = PANEL_X + 40
local ROW_W   = PANEL_W - 80
local ROW_Y0  = PANEL_Y + 80
local ROW_H   = 54
local ROW_GAP = 6

local ARR_W = 34
local ARR_H = 36
local VAL_W = 100

local BTN_H   = 44
local BTN_Y   = PANEL_Y + PANEL_H - BTN_H - 28

-- Returns the right-edge x of the control cluster for a row.
local function ctrlRight() return ROW_X + ROW_W end

local ROWS = {
    {id = "delay",      label = "Instability Delay"},
    {id = "fullscreen", label = "Fullscreen"},
}

local function rowY(i) return ROW_Y0 + (i - 1) * (ROW_H + ROW_GAP) end

local function fmtDelay(p)
    return string.format("%.1f s", p and p.instabilityStepDelay or 5.0)
end

local function fmtFullscreen(p)
    return (p and p.fullscreen) and "ON" or "OFF"
end

local function fmt(row, profile)
    if row.id == "delay"      then return fmtDelay(profile)
    elseif row.id == "fullscreen" then return fmtFullscreen(profile)
    end
    return "?"
end

function M.render(profile, inRun)
    love.graphics.setColor(0.04, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(0.10, 0.12, 0.16)
    love.graphics.rectangle("fill", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8)
    love.graphics.setColor(0.30, 0.33, 0.42)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 8)

    love.graphics.setColor(0.75, 0.80, 0.95)
    love.graphics.printf("Options", PANEL_X, PANEL_Y + 28, PANEL_W, "center")

    local font = love.graphics.getFont()

    for i, row in ipairs(ROWS) do
        local ry     = rowY(i)
        local valStr = fmt(row, profile)
        local cr     = ctrlRight()

        love.graphics.setColor(0.72, 0.76, 0.85)
        love.graphics.print(row.label, ROW_X, ry + (ARR_H - font:getHeight()) / 2)

        if row.id == "fullscreen" then
            local bw = 100
            local bx = cr - bw
            local on = profile and profile.fullscreen
            love.graphics.setColor(on and 0.18 or 0.14, on and 0.42 or 0.18, on and 0.22 or 0.22)
            love.graphics.rectangle("fill", bx, ry, bw, ARR_H, 4)
            love.graphics.setColor(0.40, 0.44, 0.55)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", bx, ry, bw, ARR_H, 4)
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.printf(valStr, bx, ry + (ARR_H - font:getHeight()) / 2, bw, "center")
        else
            local bx = cr - ARR_W
            local vx = bx - VAL_W - 4
            local ax = vx - ARR_W - 4

            -- [<]
            love.graphics.setColor(0.22, 0.26, 0.34)
            love.graphics.rectangle("fill", ax, ry, ARR_W, ARR_H, 3)
            love.graphics.setColor(1, 1, 1, 0.75)
            love.graphics.printf("<", ax, ry + (ARR_H - font:getHeight()) / 2, ARR_W, "center")

            -- value label
            love.graphics.setColor(0.85, 0.88, 0.95)
            love.graphics.printf(valStr, vx, ry + (ARR_H - font:getHeight()) / 2, VAL_W, "center")

            -- [>]
            love.graphics.setColor(0.22, 0.26, 0.34)
            love.graphics.rectangle("fill", bx, ry, ARR_W, ARR_H, 3)
            love.graphics.setColor(1, 1, 1, 0.75)
            love.graphics.printf(">", bx, ry + (ARR_H - font:getHeight()) / 2, ARR_W, "center")
        end
    end

    -- Divider
    local divY = BTN_Y - 14
    love.graphics.setColor(0.22, 0.25, 0.32)
    love.graphics.setLineWidth(1)
    love.graphics.line(PANEL_X + 24, divY, PANEL_X + PANEL_W - 24, divY)

    -- Back
    local backW = 120
    love.graphics.setColor(0.18, 0.42, 0.20)
    love.graphics.rectangle("fill", ROW_X, BTN_Y, backW, BTN_H, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf("Back", ROW_X, BTN_Y + (BTN_H - font:getHeight()) / 2, backW, "center")

    -- Exit Game (right-aligned)
    local exitW = 140
    local exitX = ROW_X + ROW_W - exitW
    love.graphics.setColor(0.45, 0.18, 0.18)
    love.graphics.rectangle("fill", exitX, BTN_Y, exitW, BTN_H, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf("Exit Game", exitX, BTN_Y + (BTN_H - font:getHeight()) / 2, exitW, "center")

    -- Quit Run (center, only when inRun)
    if inRun then
        local qw = 140
        local qx = ROW_X + (ROW_W - qw) / 2
        love.graphics.setColor(0.40, 0.18, 0.12)
        love.graphics.rectangle("fill", qx, BTN_Y, qw, BTN_H, 4)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf("Quit Run", qx, BTN_Y + (BTN_H - font:getHeight()) / 2, qw, "center")
    end
end

-- Returns one of:
--   "back" | "exit_game" | "quit_run"
--   "delay_dec" | "delay_inc"
--   "fullscreen_toggle"
-- or nil.
function M.hit(vx, vy, profile, inRun)
    local cr = ctrlRight()

    for i, row in ipairs(ROWS) do
        local ry = rowY(i)

        if row.id == "fullscreen" then
            local bw = 100
            local bx = cr - bw
            if vx >= bx and vx <= bx + bw and vy >= ry and vy <= ry + ARR_H then
                return "fullscreen_toggle"
            end
        else
            local bx = cr - ARR_W
            local vx2 = bx - VAL_W - 4
            local ax = vx2 - ARR_W - 4
            -- [<]
            if vx >= ax and vx <= ax + ARR_W and vy >= ry and vy <= ry + ARR_H then
                return row.id .. "_dec"
            end
            -- [>]
            if vx >= bx and vx <= bx + ARR_W and vy >= ry and vy <= ry + ARR_H then
                return row.id .. "_inc"
            end
        end
    end

    -- Back
    local backW = 120
    if vx >= ROW_X and vx <= ROW_X + backW and vy >= BTN_Y and vy <= BTN_Y + BTN_H then
        return "back"
    end

    -- Exit Game
    local exitW = 140
    local exitX = ROW_X + ROW_W - exitW
    if vx >= exitX and vx <= exitX + exitW and vy >= BTN_Y and vy <= BTN_Y + BTN_H then
        return "exit_game"
    end

    -- Quit Run
    if inRun then
        local qw = 140
        local qx = ROW_X + (ROW_W - qw) / 2
        if vx >= qx and vx <= qx + qw and vy >= BTN_Y and vy <= BTN_Y + BTN_H then
            return "quit_run"
        end
    end

    return nil
end

return M
