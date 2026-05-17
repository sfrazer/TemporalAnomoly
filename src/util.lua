local M = {}

local INSTABILITY_TRACK = {2, 2, 2, 3, 3, 4, 4}
M.COLORS = {"blue", "yellow", "black", "red"}

function M.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function M.drawTop(deck)
    return table.remove(deck, 1)
end

function M.drawBottom(deck)
    return table.remove(deck)
end

function M.countCubesOnBoard(state, color)
    local total = 0
    for _, cityData in pairs(state.cubes) do
        for _, periodData in pairs(cityData) do
            total = total + (periodData[color] or 0)
        end
    end
    return total
end

function M.cubeSupply(state, color)
    return 24 - M.countCubesOnBoard(state, color)
end

function M.instabilityLevel(state)
    return INSTABILITY_TRACK[state.instabilityIndex] or INSTABILITY_TRACK[#INSTABILITY_TRACK]
end

-- Call after any cube removal to auto-derive REPAIRED state.
function M.updateRepaired(state)
    for _, color in ipairs(M.COLORS) do
        if state.resolved[color] and not state.repaired[color] then
            if M.countCubesOnBoard(state, color) == 0 then
                state.repaired[color] = true
            end
        end
    end
end

return M
