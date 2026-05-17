local M = {}

local COLORS = {"blue", "yellow", "black", "red"}

function M.checkWinLose(state)
    -- Loss conditions (checked before win)
    if state.lost then
        return "lost", state.lost
    end
    if state.explosionCount >= 8 then
        return "lost", "8 Temporal Explosions reached"
    end

    local resolved = 0
    local repaired = 0
    for _, color in ipairs(COLORS) do
        if state.resolved[color] then resolved = resolved + 1 end
        if state.repaired[color] then repaired = repaired + 1 end
    end

    local d = state.difficulty
    if d == "introductory" then
        if resolved >= 2 then return "won", "2 anomalies RESOLVED" end
    elseif d == "standard" then
        if resolved >= 3 then return "won", "3 anomalies RESOLVED" end
    elseif d == "heroic" then
        if resolved >= 4 then return "won", "all 4 anomalies RESOLVED" end
        if repaired >= 2 then return "won", "2 anomalies REPAIRED" end
    elseif d == "legendary" then
        if resolved >= 4 then return "won", "all 4 anomalies RESOLVED" end
    end

    return nil
end

return M
