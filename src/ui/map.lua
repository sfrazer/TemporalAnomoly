local unpack  = table.unpack or unpack  -- LuaJIT (Love2D) vs Lua 5.2+
local cities  = require("data.cities")
local periods = require("data.periods")
local Tooltip = require("src.ui.tooltip")

local M = {}

-- Layout
local MAP_Y  = 0
local QUAD_W = 640
local QUAD_H = 270
local NODE_R = 20

-- Camera (pan + zoom, module-level)
local cam = {x = 0, y = 0, scale = 1.0, dragging = false, dragVX = 0, dragVY = 0}

-- Period accent colors {r, g, b}
local PCOLOR = {
    prehistory = {0.25, 0.52, 0.95},
    industrial = {0.90, 0.78, 0.10},
    modern     = {0.55, 0.55, 0.60},
    far_future = {0.90, 0.20, 0.20},
}

local CUBE_COLOR = {
    blue   = {0.20, 0.45, 0.92},
    yellow = {0.92, 0.82, 0.05},
    black  = {0.60, 0.60, 0.65},
    red    = {0.90, 0.15, 0.15},
}

local PERIOD_QUADS = {
    {id = "prehistory", col = 0, row = 0},
    {id = "industrial", col = 1, row = 0},
    {id = "modern",     col = 0, row = 1},
    {id = "far_future", col = 1, row = 1},
}

local PERIOD_NAME = {
    prehistory = "Prehistory",
    industrial = "Industrial Age",
    modern     = "Modern Age",
    far_future = "Far Future",
}

-- City positions within a quadrant (pixels; quadrant is 640×270)
local CITY_POS = {
    seattle     = {88,  48},
    chicago     = {375, 48},
    los_angeles = {58,  192},
    houston     = {210, 240},
    atlanta     = {430, 218},
    new_york    = {535, 88},
}

local cityById = {}
for _, c in ipairs(cities) do cityById[c.id] = c end

-- Map virtual region height (set by main when layout is known)
local mapH = QUAD_H * 2

function M.setMapHeight(h) mapH = h end

local function camToMap(vx, vy)
    return (vx - cam.x) / cam.scale,
           (vy - MAP_Y - cam.y) / cam.scale
end

local function drawConnections(qx, qy)
    local drawn = {}
    love.graphics.setColor(0.55, 0.55, 0.60, 0.45)
    love.graphics.setLineWidth(1.5)
    for _, city in ipairs(cities) do
        local p1 = CITY_POS[city.id]
        for _, nid in ipairs(city.adjacent) do
            local key = city.id < nid and (city.id..":"..nid) or (nid..":"..city.id)
            if not drawn[key] then
                drawn[key] = true
                local p2 = CITY_POS[nid]
                love.graphics.line(qx + p1[1], qy + p1[2], qx + p2[1], qy + p2[2])
            end
        end
    end
end

local function drawCity(state, cityId, periodId, qx, qy, pc, isPlayer)
    local p = CITY_POS[cityId]
    local x, y = qx + p[1], qy + p[2]
    local cubes = state.cubes[cityId][periodId]

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.circle("fill", x + 2, y + 2, NODE_R)

    -- Node fill
    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.circle("fill", x, y, NODE_R)

    -- Node border (period color)
    love.graphics.setColor(pc[1], pc[2], pc[3])
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, NODE_R)

    -- Priority City gold ring (Legendary only)
    if state.priorityCity and cityId == state.priorityCity then
        love.graphics.setColor(0.95, 0.82, 0.10, 0.90)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", x, y, NODE_R + 7)
    end

    -- Player pawn
    if isPlayer then
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.setLineWidth(2.5)
        love.graphics.circle("line", x, y, NODE_R + 5)
    end

    -- Outpost marker
    if state.outposts[cityId] then
        love.graphics.setColor(1, 0.88, 0.15)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("fill", x, y - NODE_R - 6, 5)
    end

    -- City label
    love.graphics.setColor(0.95, 0.95, 0.95)
    local name = cityById[cityId].name
    local font = love.graphics.getFont()
    local tw = font:getWidth(name)
    love.graphics.print(name, x - tw/2, y + NODE_R + 2)

    -- Cube stacks (4 colors, side by side, above node)
    local cs = 8; local gap = 2; local stackMax = 3
    local totalW = 4 * cs + 3 * gap
    local startX = x - totalW/2
    for ci, color in ipairs({"blue","yellow","black","red"}) do
        local n = math.min(cubes[color] or 0, stackMax)
        for i = 1, n do
            love.graphics.setColor(unpack(CUBE_COLOR[color]))
            love.graphics.rectangle("fill",
                startX + (ci-1)*(cs+gap),
                y - NODE_R - 4 - i*(cs+1),
                cs, cs, 1)
        end
    end

    -- Tooltip: build in virtual space (undo camera transform)
    local vcx = cam.x + x * cam.scale
    local vcy = MAP_Y + cam.y + y * cam.scale
    local vr  = (NODE_R + 8) * cam.scale
    local tipLines = {cityById[cityId].name .. " — " .. (PERIOD_NAME[periodId] or periodId)}
    local cubeStrs = {}
    for _, color in ipairs({"blue","yellow","black","red"}) do
        local n = cubes[color] or 0
        if n > 0 then
            cubeStrs[#cubeStrs+1] = n .. " " .. color
        end
    end
    if #cubeStrs > 0 then
        tipLines[#tipLines+1] = "Cubes: " .. table.concat(cubeStrs, "  ")
    else
        tipLines[#tipLines+1] = "No incident cubes"
    end
    if state.outposts[cityId] then tipLines[#tipLines+1] = "Temporal Outpost ★" end
    if state.priorityCity and cityId == state.priorityCity then
        tipLines[#tipLines+1] = "⚠ Priority City — explosion here = instant loss"
    end
    Tooltip.pushCircle(vcx, vcy, vr, table.concat(tipLines, "\n"))
end

local function drawPeriod(state, periodId, col, row)
    local qx = col * QUAD_W
    local qy = row * QUAD_H
    local pc  = PCOLOR[periodId]

    -- Background
    love.graphics.setColor(0.07, 0.09, 0.12)
    love.graphics.rectangle("fill", qx, qy, QUAD_W, QUAD_H)

    -- Colored border
    love.graphics.setColor(pc[1], pc[2], pc[3], 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", qx, qy, QUAD_W, QUAD_H)

    -- Period label (top-left)
    love.graphics.setColor(pc[1], pc[2], pc[3], 0.85)
    love.graphics.print(PERIOD_NAME[periodId], qx + 8, qy + 6)

    drawConnections(qx, qy)

    for _, city in ipairs(cities) do
        local isPlayer = (city.id == state.currentCity and periodId == state.currentPeriod)
        drawCity(state, city.id, periodId, qx, qy, pc, isPlayer)
    end
end

function M.render(state)
    love.graphics.setColor(0.05, 0.06, 0.08)
    love.graphics.rectangle("fill", 0, MAP_Y, QUAD_W*2, mapH)

    love.graphics.push()
    love.graphics.translate(cam.x, MAP_Y + cam.y)
    love.graphics.scale(cam.scale, cam.scale)

    for _, q in ipairs(PERIOD_QUADS) do
        drawPeriod(state, q.id, q.col, q.row)
    end

    love.graphics.pop()
end

function M.mousepressed(vx, vy, button)
    if button == 1 and vy >= MAP_Y and vy < MAP_Y + mapH then
        cam.dragging = true
        cam.dragVX   = vx
        cam.dragVY   = vy
    end
end

function M.mousemoved(vx, vy, dx, dy)
    if cam.dragging then
        cam.x = cam.x + dx
        cam.y = cam.y + dy
    end
end

function M.mousereleased(button)
    if button == 1 then cam.dragging = false end
end

function M.wheelmoved(vx, vy, wx, wy)
    -- Zoom toward cursor
    local factor = wy > 0 and 1.12 or (1/1.12)
    local newScale = math.max(0.35, math.min(3.5, cam.scale * factor))
    -- Adjust offset so zoom is centered on cursor position
    local mx, my = camToMap(vx, vy)
    cam.x     = vx - mx * newScale
    cam.y     = vy - MAP_Y - my * newScale
    cam.scale = newScale
end

-- Returns {city=id, period=id} or nil
function M.hitCity(vx, vy)
    if vy < MAP_Y or vy >= MAP_Y + mapH then return nil end
    local mx, my = camToMap(vx, vy)
    for _, q in ipairs(PERIOD_QUADS) do
        local qx = q.col * QUAD_W
        local qy = q.row * QUAD_H
        for _, city in ipairs(cities) do
            local p  = CITY_POS[city.id]
            local cx = qx + p[1]
            local cy = qy + p[2]
            if (mx-cx)^2 + (my-cy)^2 <= NODE_R^2 then
                return {city = city.id, period = q.id}
            end
        end
    end
    return nil
end

return M
