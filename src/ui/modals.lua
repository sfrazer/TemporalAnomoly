-- Generic list-picker modal. All love.* calls are inside functions so busted
-- can require this file without a Love2D runtime.
local Tooltip = require("src.ui.tooltip")
local M = {}

local W       = 420
local ITEM_H  = 40
local PAD     = 20
local ARROW_W = 22
local ARROW_G = 4

-- Returns a modal state table. Store it in main.lua; pass to render/click.
-- items  = array of {label=string, value=any}
-- onPick = function(value) called with chosen value, or nil on cancel
function M.new(title, items, onPick)
    return {title = title, items = items, onPick = onPick}
end

-- Reorder modal: items array is mutable; confirmed order is passed to onPick.
-- click() returns "reorder" when an arrow mutates items (keep modal open),
-- or the current items table when confirmed (passed straight to onPick).
function M.newReorder(title, items, onPick)
    return {reorder = true, title = title, items = items, onPick = onPick}
end

local function layout(modal)
    local H = PAD + 28 + PAD + #modal.items * ITEM_H + PAD + ITEM_H + PAD
    local x = (1280 - W) / 2
    local y = (720  - H) / 2
    return x, y, H
end

local function reorderLayout(modal)
    local n = #modal.items
    local H = PAD + 28 + PAD + n * ITEM_H + PAD + ITEM_H + 8 + ITEM_H + PAD
    local x = (1280 - W) / 2
    local y = (720  - H) / 2
    return x, y, H
end

local function renderReorder(modal)
    local x, y, H = reorderLayout(modal)
    local font     = love.graphics.getFont()

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
    for i, item in ipairs(modal.items) do
        local ax   = x + PAD
        local btnH = ITEM_H - 12
        local btnY = iy + 6

        -- ↑ button
        local upOn = i > 1
        love.graphics.setColor(upOn and 0.32 or 0.18, upOn and 0.36 or 0.20, upOn and 0.46 or 0.24)
        love.graphics.rectangle("fill", ax, btnY, ARROW_W, btnH, 3)
        love.graphics.setColor(1, 1, 1, upOn and 0.85 or 0.22)
        love.graphics.printf("^", ax, btnY + (btnH - font:getHeight()) / 2, ARROW_W, "center")

        -- ↓ button
        local downOn = i < #modal.items
        local bx = ax + ARROW_W + ARROW_G
        love.graphics.setColor(downOn and 0.32 or 0.18, downOn and 0.36 or 0.20, downOn and 0.46 or 0.24)
        love.graphics.rectangle("fill", bx, btnY, ARROW_W, btnH, 3)
        love.graphics.setColor(1, 1, 1, downOn and 0.85 or 0.22)
        love.graphics.printf("v", bx, btnY + (btnH - font:getHeight()) / 2, ARROW_W, "center")

        -- Label
        local lx = bx + ARROW_W + 8
        local lw = W - PAD * 2 - ARROW_W * 2 - ARROW_G - 8
        love.graphics.setColor(0.28, 0.32, 0.38)
        love.graphics.rectangle("fill", lx, iy, lw, ITEM_H - 4, 4)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(item.label, lx + 8, iy + (ITEM_H - 4 - font:getHeight()) / 2)

        iy = iy + ITEM_H
    end

    -- Confirm button
    local cy = iy + PAD
    love.graphics.setColor(0.18, 0.42, 0.20)
    love.graphics.rectangle("fill", x + PAD, cy, W - PAD * 2, ITEM_H - 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Confirm Order", x + PAD + 12, cy + 11)

    -- Cancel button
    local cancelY = cy + ITEM_H + 8
    love.graphics.setColor(0.45, 0.18, 0.18)
    love.graphics.rectangle("fill", x + PAD, cancelY, W - PAD * 2, ITEM_H - 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Cancel", x + PAD + 12, cancelY + 11)
end

local function clickReorder(modal, vx, vy)
    local x, y, H = reorderLayout(modal)
    local ax  = x + PAD
    local iy  = y + PAD + 28 + PAD
    for i = 1, #modal.items do
        local btnY = iy + 6
        local btnH = ITEM_H - 12
        -- ↑
        if i > 1 and vx >= ax and vx <= ax + ARROW_W and vy >= btnY and vy <= btnY + btnH then
            modal.items[i], modal.items[i - 1] = modal.items[i - 1], modal.items[i]
            return "reorder"
        end
        -- ↓
        local bx = ax + ARROW_W + ARROW_G
        if i < #modal.items and vx >= bx and vx <= bx + ARROW_W and vy >= btnY and vy <= btnY + btnH then
            modal.items[i], modal.items[i + 1] = modal.items[i + 1], modal.items[i]
            return "reorder"
        end
        iy = iy + ITEM_H
    end
    -- Confirm
    local cy = iy + PAD
    if vx >= x+PAD and vx <= x+W-PAD and vy >= cy and vy <= cy + ITEM_H - 4 then
        return modal.items  -- table return → main.lua dispatches to onPick(items)
    end
    -- Cancel
    local cancelY = cy + ITEM_H + 8
    if vx >= x+PAD and vx <= x+W-PAD and vy >= cancelY and vy <= cancelY + ITEM_H - 4 then
        return "cancel"
    end
    return nil
end

function M.render(modal)
    if not modal then return end
    if modal.reorder then renderReorder(modal); return end
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
        if item.disabled then
            love.graphics.setColor(0.14, 0.16, 0.20)
        else
            love.graphics.setColor(0.28, 0.32, 0.38)
        end
        love.graphics.rectangle("fill", x + PAD, iy, W - PAD*2, ITEM_H - 4, 4)
        love.graphics.setColor(item.disabled and 0.40 or 0.9,
                               item.disabled and 0.40 or 0.9,
                               item.disabled and 0.40 or 0.9)
        love.graphics.print(item.label, x + PAD + 12, iy + 11)
        if item.tip then
            Tooltip.pushModal(x + PAD, iy, W - PAD*2, ITEM_H - 4, item.tip)
        end
        iy = iy + ITEM_H
    end

    -- Cancel
    local cancelY = iy + PAD
    love.graphics.setColor(0.45, 0.18, 0.18)
    love.graphics.rectangle("fill", x + PAD, cancelY, W - PAD*2, ITEM_H - 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Cancel", x + PAD + 12, cancelY + 11)
end

-- Returns the chosen value, "cancel", "reorder" (reorder arrow hit), or nil.
function M.click(modal, vx, vy)
    if not modal then return nil end
    if modal.reorder then return clickReorder(modal, vx, vy) end
    local x, y, H = layout(modal)

    local iy = y + PAD + 28 + PAD
    for _, item in ipairs(modal.items) do
        if not item.disabled then
            if vx >= x+PAD and vx <= x+W-PAD and vy >= iy and vy <= iy+ITEM_H-4 then
                return item.value
            end
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
