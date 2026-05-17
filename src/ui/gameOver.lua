local M = {}

local VW, VH = 1280, 720

local CARD_X = 320
local CARD_Y = 148
local CARD_W = 640
local CARD_H = 424

local BTN_W   = 176
local BTN_H   = 38
local BTN_GAP = 16
local BTN_Y   = CARD_Y + CARD_H - 58
local BTN1_X  = CARD_X + 40
local BTN2_X  = BTN1_X + BTN_W + BTN_GAP
local BTN3_X  = BTN2_X + BTN_W + BTN_GAP

local BUTTONS = {
    {id = "play_again",     label = "Play Again",     x = BTN1_X},
    {id = "return_to_shop", label = "Return to Shop", x = BTN2_X},
    {id = "change_role",    label = "Change Role",    x = BTN3_X},
}

function M.render(gameResult)
    if not gameResult then return end
    local won = gameResult.result == "won"

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, VW, VH)

    -- Card body
    love.graphics.setColor(0.07, 0.08, 0.12)
    love.graphics.rectangle("fill", CARD_X, CARD_Y, CARD_W, CARD_H, 8)

    -- Card border
    love.graphics.setColor(
        won and 0.22 or 0.50,
        won and 0.55 or 0.14,
        won and 0.28 or 0.14)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", CARD_X, CARD_Y, CARD_W, CARD_H, 8)

    -- Header band
    love.graphics.setColor(
        won and 0.09 or 0.20,
        won and 0.22 or 0.07,
        won and 0.12 or 0.07)
    love.graphics.rectangle("fill", CARD_X + 2, CARD_Y + 2, CARD_W - 4, 50, 7)
    love.graphics.rectangle("fill", CARD_X + 2, CARD_Y + 30, CARD_W - 4, 22)

    -- Title
    love.graphics.setColor(
        won and 0.38 or 0.92,
        won and 0.90 or 0.28,
        won and 0.48 or 0.28)
    love.graphics.printf(won and "VICTORY" or "DEFEAT", CARD_X, CARD_Y + 16, CARD_W, "center")

    -- Divider
    love.graphics.setColor(0.18, 0.22, 0.32)
    love.graphics.setLineWidth(1)
    love.graphics.line(CARD_X + 24, CARD_Y + 58, CARD_X + CARD_W - 24, CARD_Y + 58)

    -- Reason
    love.graphics.setColor(0.80, 0.82, 0.88)
    love.graphics.printf(gameResult.reason or "", CARD_X + 24, CARD_Y + 70, CARD_W - 48, "center")

    local nextY = CARD_Y + 132

    -- RP earned
    if gameResult.earnedRP and gameResult.earnedRP > 0 then
        love.graphics.setColor(0.90, 0.82, 0.30)
        love.graphics.printf("+" .. gameResult.earnedRP .. " RP earned",
                             CARD_X, nextY, CARD_W, "center")
        nextY = nextY + 36
    end

    -- Newly unlocked roles
    if gameResult.newUnlocks and #gameResult.newUnlocks > 0 then
        love.graphics.setColor(0.52, 0.90, 0.60)
        love.graphics.printf("Unlocked: " .. table.concat(gameResult.newUnlocks, ", "),
                             CARD_X + 24, nextY, CARD_W - 48, "center")
    end

    -- Buttons
    for _, btn in ipairs(BUTTONS) do
        love.graphics.setColor(0.12, 0.16, 0.24)
        love.graphics.rectangle("fill", btn.x, BTN_Y, BTN_W, BTN_H, 5)
        love.graphics.setColor(0.28, 0.34, 0.52)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", btn.x, BTN_Y, BTN_W, BTN_H, 5)
        love.graphics.setColor(0.72, 0.78, 0.92)
        love.graphics.printf(btn.label, btn.x, BTN_Y + 11, BTN_W, "center")
    end
end

function M.hit(vx, vy)
    if vy < BTN_Y or vy > BTN_Y + BTN_H then return nil end
    for _, btn in ipairs(BUTTONS) do
        if vx >= btn.x and vx <= btn.x + BTN_W then
            return btn.id
        end
    end
    return nil
end

return M
