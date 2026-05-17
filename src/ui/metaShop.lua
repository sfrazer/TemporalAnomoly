local unpack = table.unpack or unpack
local shop   = require("data.shop")

local M = {}

local VW, VH = 1280, 720

local COL_X   = {15, 445, 875}
local COL_W   = 390
local ITEM_H  = 86
local ITEMS_Y = 98
local BTN_W   = 26
local BTN_H   = 22
-- [-] button x-offset within a column; [count] at +28, [+] at +56
local DEC_OFF = 296

local SECTIONS = {
    {title = "Starting Bonuses", items = shop.startingBonuses, stype = "bonus"},
    {title = "Deck Upgrades",    items = shop.deckCards,       stype = "deck"},
    {title = "Challenge Mods",   items = shop.challengeMods,   stype = "mod"},
}

local function getCount(shopState, stype, id)
    if stype == "bonus" then return shopState.bonusSelections[id] or 0 end
    if stype == "deck"  then return shopState.deckSelections[id]  or 0 end
    return 0
end

local function modOn(shopState, id)
    for _, mid in ipairs(shopState.challengeModIds) do
        if mid == id then return true end
    end
    return false
end

local function totalCost(shopState)
    local c = 0
    for _, item in ipairs(shop.startingBonuses) do
        c = c + item.cost * (shopState.bonusSelections[item.id] or 0)
    end
    for _, item in ipairs(shop.deckCards) do
        c = c + item.cost * (shopState.deckSelections[item.id] or 0)
    end
    return c
end

local function bonusRPTotal(shopState)
    local rp = 0
    for _, item in ipairs(shop.challengeMods) do
        if modOn(shopState, item.id) then rp = rp + item.bonusRP end
    end
    return rp
end

function M.render(shopState, rpBalance)
    local cost      = totalCost(shopState)
    local remaining = (rpBalance or 0) - cost

    love.graphics.setColor(0.04, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, VW, VH)

    love.graphics.setColor(0.75, 0.80, 0.95)
    love.graphics.printf("Research Lab", 0, 18, VW, "center")

    love.graphics.setColor(0.90, 0.82, 0.30)
    love.graphics.printf("Total RP: " .. (rpBalance or 0), 0, 18, VW - 20, "right")

    for ci, section in ipairs(SECTIONS) do
        local cx = COL_X[ci]

        love.graphics.setColor(0.48, 0.52, 0.68)
        love.graphics.printf(section.title, cx, 62, COL_W, "center")
        love.graphics.setColor(0.22, 0.25, 0.35)
        love.graphics.rectangle("fill", cx, 88, COL_W, 2)

        for ri, item in ipairs(section.items) do
            local iy = ITEMS_Y + (ri - 1) * ITEM_H

            love.graphics.setColor(0.10, 0.12, 0.17)
            love.graphics.rectangle("fill", cx, iy, COL_W, ITEM_H - 4, 5)

            -- Name
            love.graphics.setColor(0.88, 0.90, 0.96)
            love.graphics.print(item.name, cx + 8, iy + 7)

            -- Cost / bonus label (top-right)
            if section.stype == "mod" then
                love.graphics.setColor(0.90, 0.75, 0.30)
                love.graphics.printf("+" .. item.bonusRP .. " RP", cx, iy + 7, COL_W - 8, "right")
            else
                local cnt = getCount(shopState, section.stype, item.id)
                love.graphics.setColor(cnt > 0 and 0.90 or 0.48, cnt > 0 and 0.68 or 0.52, 0.28)
                love.graphics.printf(item.cost .. " RP", cx, iy + 7, COL_W - 8, "right")
            end

            -- Description
            love.graphics.setColor(0.52, 0.55, 0.64)
            love.graphics.printf(item.description, cx + 8, iy + 27, COL_W - 16, "left")

            -- Controls
            if section.stype == "mod" then
                local on = modOn(shopState, item.id)
                love.graphics.setColor(on and 0.18 or 0.12, on and 0.42 or 0.16, on and 0.22 or 0.14)
                love.graphics.rectangle("fill", cx + COL_W - 68, iy + 53, 60, BTN_H, 4)
                love.graphics.setColor(on and 0.50 or 0.38, on and 0.90 or 0.44, on and 0.58 or 0.42)
                love.graphics.printf(on and "ON" or "OFF", cx + COL_W - 68, iy + 55, 60, "center")
            else
                local cnt      = getCount(shopState, section.stype, item.id)
                local maxCnt   = item.maxCount or item.maxCopies or 1
                local canAdd   = cnt < maxCnt and (remaining >= item.cost)
                local canSub   = cnt > 0
                local bx       = cx + DEC_OFF
                local by       = iy + 53

                -- [-]
                love.graphics.setColor(canSub and 0.28 or 0.12, 0.12, 0.12)
                love.graphics.rectangle("fill", bx, by, BTN_W, BTN_H, 3)
                love.graphics.setColor(canSub and 0.85 or 0.35, 0.32, 0.32)
                love.graphics.printf("-", bx, by + 3, BTN_W, "center")

                -- count
                love.graphics.setColor(0.78, 0.80, 0.88)
                love.graphics.printf(tostring(cnt), bx + BTN_W + 2, by + 3, 24, "center")

                -- [+]
                local px = bx + BTN_W + 2 + 24 + 2
                love.graphics.setColor(canAdd and 0.14 or 0.10, canAdd and 0.28 or 0.12, canAdd and 0.14 or 0.10)
                love.graphics.rectangle("fill", px, by, BTN_W, BTN_H, 3)
                love.graphics.setColor(canAdd and 0.30 or 0.22, canAdd and 0.78 or 0.30, canAdd and 0.38 or 0.22)
                love.graphics.printf("+", px, by + 3, BTN_W, "center")
            end
        end
    end

    -- Footer
    local fy = 554
    love.graphics.setColor(0.16, 0.18, 0.24)
    love.graphics.rectangle("fill", 0, fy, VW, VH - fy)
    love.graphics.setColor(0.24, 0.27, 0.36)
    love.graphics.rectangle("fill", 0, fy, VW, 2)

    -- RP breakdown
    local affordable = remaining >= 0
    love.graphics.setColor(0.60, 0.63, 0.75)
    love.graphics.printf("Total RP: " .. (rpBalance or 0), 20, fy + 14, 250, "left")
    love.graphics.setColor(0.88, 0.68, 0.28)
    love.graphics.printf("Allocated: " .. cost, 20, fy + 36, 250, "left")
    love.graphics.setColor(affordable and 0.38 or 0.88, affordable and 0.88 or 0.32, affordable and 0.42 or 0.30)
    love.graphics.printf("Remaining: " .. remaining, 280, fy + 36, 250, "left")

    -- Bonus RP from mods
    local bonus = bonusRPTotal(shopState)
    if bonus > 0 then
        love.graphics.setColor(0.90, 0.75, 0.30)
        love.graphics.printf("+" .. bonus .. " RP/run from mods", 540, fy + 22, 360, "center")
    end

    -- Start Run button
    love.graphics.setColor(affordable and 0.18 or 0.14, affordable and 0.50 or 0.16, affordable and 0.24 or 0.15)
    love.graphics.rectangle("fill", 988, fy + 10, 272, 42, 6)
    love.graphics.setColor(affordable and 0.80 or 0.38, affordable and 0.92 or 0.38, affordable and 0.84 or 0.40)
    love.graphics.printf("Start Run", 988, fy + 22, 272, "center")
end

-- Returns an action table or nil.
-- {type="start"} | {type="increment",stype,id} | {type="decrement",stype,id} | {type="toggle",id}
function M.hit(vx, vy, shopState, rpBalance)
    local cost      = totalCost(shopState)
    local remaining = (rpBalance or 0) - cost

    -- Start Run button
    if vx >= 988 and vx <= 1260 and vy >= 564 and vy <= 606 then
        if remaining >= 0 then return {type = "start"} end
        return nil
    end

    for ci, section in ipairs(SECTIONS) do
        local cx = COL_X[ci]
        for ri, item in ipairs(section.items) do
            local iy = ITEMS_Y + (ri - 1) * ITEM_H
            if vx >= cx and vx <= cx + COL_W and vy >= iy and vy <= iy + ITEM_H - 4 then
                if section.stype == "mod" then
                    if vx >= cx + COL_W - 68 and vx <= cx + COL_W - 8 and vy >= iy + 53 and vy <= iy + 53 + BTN_H then
                        return {type = "toggle", id = item.id}
                    end
                else
                    local bx = cx + DEC_OFF
                    local by = iy + 53
                    if vy >= by and vy <= by + BTN_H then
                        -- [-]
                        if vx >= bx and vx <= bx + BTN_W then
                            return {type = "decrement", stype = section.stype, id = item.id}
                        end
                        -- [+]
                        local px = bx + BTN_W + 2 + 24 + 2
                        if vx >= px and vx <= px + BTN_W then
                            local cnt    = getCount(shopState, section.stype, item.id)
                            local maxCnt = item.maxCount or item.maxCopies or 1
                            if cnt < maxCnt and remaining >= item.cost then
                                return {type = "increment", stype = section.stype, id = item.id}
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

return M
