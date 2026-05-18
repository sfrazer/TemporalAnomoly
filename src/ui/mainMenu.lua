local M = {}

local BTN_W   = 400
local BTN_H   = 50
local BTN_GAP = 14
local BTN_X   = (1280 - BTN_W) / 2

local TITLE_Y   = 80
local PROFILE_Y = 170
local BTN_Y0    = 230

local function btnY(i) return BTN_Y0 + (i - 1) * (BTN_H + BTN_GAP) end

local BUTTONS = {
    {id = "resume",         label = "Resume Last Run", color = {0.18, 0.42, 0.20}},
    {id = "new_run",        label = "New Run",         color = {0.20, 0.24, 0.30}},
    {id = "change_profile", label = "Change Profile",  color = {0.20, 0.24, 0.30}},
    {id = "options",        label = "Options",         color = {0.20, 0.24, 0.30}},
}

function M.render(profile)
    love.graphics.setColor(0.04, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(0.75, 0.80, 0.95)
    love.graphics.printf("Temporal Anomaly", 0, TITLE_Y, 1280, "center")

    local name = profile and profile.name
    if name and name ~= "" then
        love.graphics.setColor(0.50, 0.55, 0.68)
        love.graphics.printf(name, 0, PROFILE_Y, 1280, "center")
    end

    local hasRun = profile and profile.activeRun ~= nil
    local font   = love.graphics.getFont()

    for i, btn in ipairs(BUTTONS) do
        local y       = btnY(i)
        local enabled = btn.id ~= "resume" or hasRun

        if not enabled then
            love.graphics.setColor(0.12, 0.14, 0.18)
        else
            love.graphics.setColor(unpack(btn.color))
        end
        love.graphics.rectangle("fill", BTN_X, y, BTN_W, BTN_H, 4)

        if not enabled then
            love.graphics.setColor(0.22, 0.24, 0.30)
        else
            love.graphics.setColor(0.35, 0.40, 0.52)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", BTN_X, y, BTN_W, BTN_H, 4)

        love.graphics.setColor(1, 1, 1, enabled and 0.90 or 0.28)
        local tw = font:getWidth(btn.label)
        love.graphics.print(btn.label, BTN_X + (BTN_W - tw) / 2, y + (BTN_H - font:getHeight()) / 2)
    end
end

-- Returns "resume"|"new_run"|"change_profile"|"options"|nil.
-- Resume is only returned when profile.activeRun is set.
function M.hit(vx, vy, profile)
    local hasRun = profile and profile.activeRun ~= nil
    for i, btn in ipairs(BUTTONS) do
        local y       = btnY(i)
        local enabled = btn.id ~= "resume" or hasRun
        if enabled and vx >= BTN_X and vx <= BTN_X + BTN_W and vy >= y and vy <= y + BTN_H then
            return btn.id
        end
    end
    return nil
end

return M
