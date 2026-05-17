local unpack = table.unpack or unpack  -- LuaJIT (Love2D) vs Lua 5.2+
local roles  = require("data.roles")

local M = {}

-- Grid: 4 columns, cards sized to fill a 1280×720 virtual canvas
local COLS    = 4
local CARD_W  = 260
local CARD_H  = 150
local CARD_GAP = 18

local LOCKED_COLOR = {0.40, 0.40, 0.45}

local function gridPositions()
    local n      = #roles
    local rows   = math.ceil(n / COLS)
    local totalW = COLS * CARD_W + (COLS - 1) * CARD_GAP
    local totalH = rows * CARD_H + (rows - 1) * CARD_GAP
    local startX = (1280 - totalW) / 2
    local startY = 80 + (720 - 80 - totalH) / 2

    local positions = {}
    for i, role in ipairs(roles) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        positions[i] = {
            x    = startX + col * (CARD_W + CARD_GAP),
            y    = startY + row * (CARD_H + CARD_GAP),
            role = role,
        }
    end
    return positions
end

function M.render(profile)
    -- Background
    love.graphics.setColor(0.04, 0.05, 0.08)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Title
    love.graphics.setColor(0.75, 0.80, 0.95)
    love.graphics.printf("Select Your Role", 0, 28, 1280, "center")

    local positions = gridPositions()
    local font = love.graphics.getFont()

    for _, pos in ipairs(positions) do
        local role   = pos.role
        local x, y  = pos.x, pos.y
        local unlocks = profile and profile.roleUnlocks or {}
        local locked = not (role.unlocked or unlocks[role.id])
        local rc     = locked and LOCKED_COLOR or role.color

        -- Card body
        love.graphics.setColor(0.10, 0.12, 0.16)
        love.graphics.rectangle("fill", x, y, CARD_W, CARD_H, 6)

        -- Accent top bar
        love.graphics.setColor(rc[1], rc[2], rc[3], locked and 0.30 or 0.75)
        love.graphics.rectangle("fill", x, y, CARD_W, 6, 6)
        love.graphics.rectangle("fill", x, y, CARD_W, 3)

        -- Border
        love.graphics.setColor(rc[1], rc[2], rc[3], locked and 0.25 or 0.80)
        love.graphics.setLineWidth(locked and 1 or 2)
        love.graphics.rectangle("line", x, y, CARD_W, CARD_H, 6)

        -- Role name
        love.graphics.setColor(locked and 0.40 or 0.92,
                                locked and 0.40 or 0.92,
                                locked and 0.45 or 0.95)
        love.graphics.printf(role.name, x + 8, y + 14, CARD_W - 16, "center")

        -- Description
        love.graphics.setColor(locked and 0.28 or 0.70,
                                locked and 0.28 or 0.73,
                                locked and 0.32 or 0.78)
        love.graphics.printf(role.description, x + 10, y + 42, CARD_W - 20, "center")

        -- Unlock hint for locked roles
        if locked then
            love.graphics.setColor(0.50, 0.50, 0.55)
            love.graphics.printf(role.unlockHint or "Locked",
                                 x + 8, y + CARD_H - 24, CARD_W - 16, "center")
        end
    end
end

-- Returns role id if an unlocked card was clicked, nil otherwise
function M.hit(vx, vy, profile)
    local positions = gridPositions()
    local unlocks = profile and profile.roleUnlocks or {}
    for _, pos in ipairs(positions) do
        local locked = not (pos.role.unlocked or unlocks[pos.role.id])
        if locked then goto continue end
        if vx >= pos.x and vx <= pos.x + CARD_W
        and vy >= pos.y and vy <= pos.y + CARD_H then
            return pos.role.id
        end
        ::continue::
    end
    return nil
end

return M
