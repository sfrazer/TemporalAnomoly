local unpack = table.unpack or unpack  -- LuaJIT (Love2D) vs Lua 5.2+

local M = {}

local SLOT_COUNT = 3
local CARD_W     = 320
local CARD_H     = 210
local CARD_GAP   = 24
local TOTAL_W    = SLOT_COUNT * CARD_W + (SLOT_COUNT - 1) * CARD_GAP
local START_X    = (1280 - TOTAL_W) / 2
local CARD_Y     = (720 - CARD_H) / 2

local DEL_H      = 28
local DEL_PAD    = 10
local DEL_Y_OFF  = CARD_H - DEL_H - DEL_PAD

local ROLE_NAME = {
    chronologist          = "Chronologist",
    physicist             = "Physicist",
    coordinator           = "Coordinator",
    temporal_isolationist = "Temporal Isolationist",
    engineer              = "Engineer",
    researcher            = "Researcher",
    failsafe_designer     = "Failsafe Designer",
    temporal_analyst      = "Temporal Analyst",
}

local DIFF_LABEL = {
    introductory = "Introductory",
    standard     = "Standard",
    heroic       = "Heroic",
    legendary    = "Legendary",
}

local function cardX(slot) return START_X + (slot - 1) * (CARD_W + CARD_GAP) end

-- profiles: array of [slot] = profile_table_or_nil
function M.render(profiles)
    love.graphics.setColor(0.04, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    love.graphics.setColor(0.75, 0.80, 0.95)
    love.graphics.printf("Select Profile", 0, 30, 1280, "center")

    for slot = 1, SLOT_COUNT do
        local x       = cardX(slot)
        local y       = CARD_Y
        local profile = profiles[slot]

        love.graphics.setColor(0.10, 0.12, 0.16)
        love.graphics.rectangle("fill", x, y, CARD_W, CARD_H, 6)

        if profile then
            love.graphics.setColor(0.35, 0.60, 0.88, 0.80)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, CARD_W, CARD_H, 6)

            love.graphics.setColor(0.88, 0.90, 0.95)
            local displayName = (profile.name and profile.name ~= "") and profile.name or ("Profile " .. slot)
            love.graphics.printf(displayName, x + 10, y + 14, CARD_W - 20, "center")

            if profile.activeRun then
                local run = profile.activeRun
                love.graphics.setColor(0.40, 0.80, 0.45)
                love.graphics.printf("Active Run", x + 10, y + 46, CARD_W - 20, "center")

                local roleName = ROLE_NAME[run.role] or (run.role or "?")
                local diffLabel = DIFF_LABEL[run.difficulty] or (run.difficulty or "?")
                love.graphics.setColor(0.68, 0.70, 0.78)
                love.graphics.printf(roleName, x + 10, y + 74, CARD_W - 20, "center")
                love.graphics.printf(diffLabel .. "  ·  Turn " .. (run.turn or 1),
                                     x + 10, y + 98, CARD_W - 20, "center")
                love.graphics.setColor(0.50, 0.53, 0.60)
                love.graphics.printf("Click to resume", x + 10, y + 122, CARD_W - 20, "center")
            else
                love.graphics.setColor(0.50, 0.53, 0.60)
                love.graphics.printf("No active run", x + 10, y + 60, CARD_W - 20, "center")
                love.graphics.printf("Click to start new run", x + 10, y + 86, CARD_W - 20, "center")
            end

            -- Delete button
            love.graphics.setColor(0.40, 0.12, 0.12)
            love.graphics.rectangle("fill", x + DEL_PAD, y + DEL_Y_OFF,
                                    CARD_W - 2 * DEL_PAD, DEL_H, 4)
            love.graphics.setColor(0.85, 0.35, 0.35)
            love.graphics.printf("Delete", x + DEL_PAD, y + DEL_Y_OFF + 6,
                                  CARD_W - 2 * DEL_PAD, "center")
        else
            love.graphics.setColor(0.22, 0.25, 0.32, 0.65)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x, y, CARD_W, CARD_H, 6)

            love.graphics.setColor(0.38, 0.41, 0.48)
            love.graphics.printf("Profile " .. slot, x + 10, y + 14, CARD_W - 20, "center")
            love.graphics.printf("Empty", x + 10, y + 60, CARD_W - 20, "center")
            love.graphics.setColor(0.28, 0.32, 0.40)
            love.graphics.printf("Click to create", x + 10, y + 84, CARD_W - 20, "center")
        end
    end
end

-- Returns {action="select"|"delete", slot=n} or nil.
-- "delete" is only returned when the click lands on the delete button of an
-- existing profile; the caller is responsible for checking profiles[slot].
function M.hit(vx, vy)
    for slot = 1, SLOT_COUNT do
        local x = cardX(slot)
        local y = CARD_Y
        if vx >= x and vx <= x + CARD_W and vy >= y and vy <= y + CARD_H then
            local dy = y + DEL_Y_OFF
            if vy >= dy and vy <= dy + DEL_H then
                return {action = "delete", slot = slot}
            end
            return {action = "select", slot = slot}
        end
    end
    return nil
end

return M
