-- Tooltip renderer. Call setMouse each frame (via mousemoved), push()
-- hit areas during each render pass, then call render() last.
-- Areas are cleared at the end of render() so nothing carries over.

local M = {}

local _mx, _my = 0, 0
local _areas   = {}

function M.setMouse(vx, vy)
    _mx, _my = vx, vy
end

-- Rectangular hit area.
function M.push(x, y, w, h, text)
    _areas[#_areas + 1] = {x=x, y=y, w=w, h=h, text=text}
end

-- Circular hit area (for map nodes).
function M.pushCircle(cx, cy, r, text)
    _areas[#_areas + 1] = {cx=cx, cy=cy, r=r, text=text, circle=true}
end

function M.render()
    -- Find the first matching area.
    local tip = nil
    for _, a in ipairs(_areas) do
        local hit
        if a.circle then
            hit = (_mx - a.cx)^2 + (_my - a.cy)^2 <= a.r^2
        else
            hit = _mx >= a.x and _mx <= a.x + a.w
               and _my >= a.y and _my <= a.y + a.h
        end
        if hit then tip = a.text; break end
    end
    _areas = {}   -- clear for next frame

    if not tip then return end

    local font   = love.graphics.getFont()
    local maxW   = 300
    local pad    = 7
    local lineH  = font:getHeight() * 1.15
    local _, lines = font:getWrap(tip, maxW)
    local bw     = maxW + pad * 2
    local bh     = #lines * lineH + pad * 2

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
    love.graphics.setColor(0.86, 0.89, 0.95)
    love.graphics.printf(tip, tx + pad, ty + pad, maxW, "left")
end

return M
