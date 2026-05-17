-- Color+shape coding for accessibility: each anomaly color maps to a
-- distinct shape so the game is playable without relying on hue alone.
--   Blue (Prehistory)   → circle  ●
--   Yellow (Industrial) → triangle ▲
--   Black (Modern)      → square  ■
--   Red (Far Future)    → diamond ◆

local M = {}

-- Short labels: K for blacK avoids the B/B collision with Blue.
M.LABEL = {blue = "B", yellow = "Y", black = "K", red = "R"}

-- Draw the shape for `color` centered at (cx, cy) fitting within `size` px.
-- mode: "fill" (default) or "line"
function M.draw(color, cx, cy, size, mode)
    mode   = mode or "fill"
    local s = size * 0.5
    if color == "blue" then
        love.graphics.circle(mode, cx, cy, s)
    elseif color == "yellow" then
        love.graphics.polygon(mode,
            cx,     cy - s,
            cx + s, cy + s,
            cx - s, cy + s)
    elseif color == "black" then
        love.graphics.rectangle(mode, cx - s, cy - s, size, size)
    elseif color == "red" then
        love.graphics.polygon(mode,
            cx,     cy - s,
            cx + s, cy,
            cx,     cy + s,
            cx - s, cy)
    end
end

return M
