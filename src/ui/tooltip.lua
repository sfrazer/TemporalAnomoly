-- Tooltip renderer. Call setMouse each frame (via mousemoved), push()
-- hit areas during each render pass, then call render() last.
-- Areas are cleared at the end of render() so nothing carries over.
--
-- Content can be:
--   string  — plain text, word-wrapped at 300px
--   table   — array of segment tables {t=string, r=, g=, b=, bold=bool}
--             Segments render inline; "\n" inside t causes a line break.

local M = {}

local _mx, _my   = 0, 0
local _areas     = {}
local _suppressed = false

function M.setMouse(vx, vy)
    _mx, _my = vx, vy
end

-- Rectangular hit area. content = string or segment table.
function M.push(x, y, w, h, content)
    _areas[#_areas + 1] = {x=x, y=y, w=w, h=h, content=content}
end

-- Circular hit area (for map nodes). content = string or segment table.
function M.pushCircle(cx, cy, r, content)
    _areas[#_areas + 1] = {cx=cx, cy=cy, r=r, content=content, circle=true}
end

local MAX_W = 300
local PAD   = 7

local function lineCount(content, font)
    if type(content) == "string" then
        local _, lines = font:getWrap(content, MAX_W)
        return #lines
    end
    local n = 1
    for _, seg in ipairs(content) do
        for _ in (seg.t or ""):gmatch("\n") do n = n + 1 end
    end
    return n
end

local function drawContent(content, tx, ty, font, lineH)
    if type(content) == "string" then
        love.graphics.setColor(0.86, 0.89, 0.95)
        love.graphics.printf(content, tx + PAD, ty + PAD, MAX_W, "left")
        return
    end
    -- Segment table: render inline, honouring \n and bold flag.
    local cx = tx + PAD
    local cy = ty + PAD
    for _, seg in ipairs(content) do
        love.graphics.setColor(seg.r or 0.86, seg.g or 0.89, seg.b or 0.95)
        local text = seg.t or ""
        -- Walk through chunks split on \n.
        local pos = 1
        while pos <= #text do
            local nl    = text:find("\n", pos, true)
            local chunk = nl and text:sub(pos, nl - 1) or text:sub(pos)
            if seg.bold then
                -- Simulate bold: double-print with 1px x-offset.
                love.graphics.print(chunk, cx + 1, cy)
            end
            love.graphics.print(chunk, cx, cy)
            if nl then
                cx  = tx + PAD
                cy  = cy + lineH
                pos = nl + 1
            else
                cx  = cx + font:getWidth(chunk)
                break
            end
        end
    end
end

-- Call before render() to skip tooltip display this frame (e.g. when a modal is open).
function M.suppress()
    _suppressed = true
end

function M.render()
    if _suppressed then
        _areas     = {}
        _suppressed = false
        return
    end
    -- Find the first matching area.
    local content = nil
    for _, a in ipairs(_areas) do
        local hit
        if a.circle then
            hit = (_mx - a.cx)^2 + (_my - a.cy)^2 <= a.r^2
        else
            hit = _mx >= a.x and _mx <= a.x + a.w
               and _my >= a.y and _my <= a.y + a.h
        end
        if hit then content = a.content; break end
    end
    _areas = {}   -- clear for next frame

    if not content then return end

    local font  = love.graphics.getFont()
    local lineH = font:getHeight() * 1.15
    local bw    = MAX_W + PAD * 2
    local bh    = lineCount(content, font) * lineH + PAD * 2

    local tx = _mx + 16
    local ty = _my + 16
    if tx + bw > 1278 then tx = _mx - bw - 6 end
    if ty + bh > 718  then ty = _my - bh - 6 end
    tx = math.max(2, tx)
    ty = math.max(2, ty)

    love.graphics.setColor(0.07, 0.09, 0.14, 0.96)
    love.graphics.rectangle("fill", tx, ty, bw, bh, 4)
    love.graphics.setColor(0.28, 0.34, 0.52)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", tx, ty, bw, bh, 4)

    drawContent(content, tx, ty, font, lineH)
end

return M
