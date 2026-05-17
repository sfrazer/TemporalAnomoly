-- Generic list-picker modal. All love.* calls are inside functions so busted
-- can require this file without a Love2D runtime.
local M = {}

local W = 420
local ITEM_H = 40
local PAD    = 20

-- Returns a modal state table. Store it in main.lua; pass to render/click.
-- items  = array of {label=string, value=any}
-- onPick = function(value) called with chosen value, or nil on cancel
function M.new(title, items, onPick)
    return {title = title, items = items, onPick = onPick}
end

local function layout(modal)
    local H = PAD + 28 + PAD + #modal.items * ITEM_H + PAD + ITEM_H + PAD
    local x = (1280 - W) / 2
    local y = (720  - H) / 2
    return x, y, H
end

function M.render(modal)
    if not modal then return end
    local x, y, H = layout(modal)

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(0.14, 0.16, 0.20)
    love.graphics.rectangle("fill", x, y, W, H, 8)
    love.graphics.setColor(0.45, 0.5, 0.6)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, W, H, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(modal.title, x + PAD, y + PAD)

    local iy = y + PAD + 28 + PAD
    for _, item in ipairs(modal.items) do
        love.graphics.setColor(0.28, 0.32, 0.38)
        love.graphics.rectangle("fill", x + PAD, iy, W - PAD*2, ITEM_H - 4, 4)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(item.label, x + PAD + 12, iy + 11)
        iy = iy + ITEM_H
    end

    -- Cancel
    local cancelY = iy + PAD
    love.graphics.setColor(0.45, 0.18, 0.18)
    love.graphics.rectangle("fill", x + PAD, cancelY, W - PAD*2, ITEM_H - 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Cancel", x + PAD + 12, cancelY + 11)
end

-- Returns the chosen value, "cancel", or nil if click didn't land on the modal.
function M.click(modal, vx, vy)
    if not modal then return nil end
    local x, y, H = layout(modal)

    local iy = y + PAD + 28 + PAD
    for _, item in ipairs(modal.items) do
        if vx >= x+PAD and vx <= x+W-PAD and vy >= iy and vy <= iy+ITEM_H-4 then
            return item.value
        end
        iy = iy + ITEM_H
    end

    local cancelY = iy + PAD
    if vx >= x+PAD and vx <= x+W-PAD and vy >= cancelY and vy <= cancelY+ITEM_H-4 then
        return "cancel"
    end

    return nil
end

return M
