local util    = require("src.util")
local Mod     = require("src.state.modifiers")
local cities  = require("data.cities")
local periods = require("data.periods")

local cityById = {}
for _, c in ipairs(cities) do cityById[c.id] = c end

local PERIOD_IDS = {}
for _, p in ipairs(periods) do PERIOD_IDS[#PERIOD_IDS + 1] = p.id end

local M = {}

local function takeFromHand(hand, pred, n)
    n = n or 1
    local removed = {}
    for i = #hand, 1, -1 do
        if #removed >= n then break end
        if pred(hand[i]) then
            removed[#removed + 1] = table.remove(hand, i)
        end
    end
    if #removed < n then
        for _, c in ipairs(removed) do hand[#hand + 1] = c end
        return false
    end
    return removed
end

function M.tryTravel(state, destCity, destPeriod)
    destPeriod = destPeriod or state.currentPeriod

    if destCity == state.currentCity and destPeriod == state.currentPeriod then
        return false, "already at destination"
    end

    local from = {city = state.currentCity, period = state.currentPeriod}
    local to   = {city = destCity,          period = destPeriod}

    if not Mod.canTravel(state, from, to) then
        return false, "travel blocked"
    end

    if destCity == state.currentCity then
        if not state.outposts[state.currentCity] then
            return false, "no Temporal Outpost in " .. state.currentCity
        end
        state.currentPeriod = destPeriod
        Mod.onArrive(state, {city = state.currentCity, period = state.currentPeriod})
        return true
    end

    if destPeriod ~= state.currentPeriod then
        return false, "cannot change both city and period in one Travel action"
    end

    for _, nid in ipairs(cityById[state.currentCity].adjacent) do
        if nid == destCity then
            state.currentCity = destCity
            Mod.onArrive(state, {city = state.currentCity, period = state.currentPeriod})
            return true
        end
    end

    return false, destCity .. " is not adjacent to " .. state.currentCity
end

function M.tryTeleport(state, cardCity, cardPeriod)
    local removed = takeFromHand(state.hand, function(c)
        return c.type == "city" and c.city == cardCity and c.period == cardPeriod
    end)
    if not removed then
        return false, "no " .. cardCity .. "/" .. cardPeriod .. " card in hand"
    end
    state.playerDiscard[#state.playerDiscard + 1] = removed[1]
    state.currentCity   = cardCity
    state.currentPeriod = cardPeriod
    Mod.onArrive(state, {city = state.currentCity, period = state.currentPeriod})
    return true
end

function M.tryTeleportAlt(state, destCity, destPeriod)
    local removed = takeFromHand(state.hand, function(c)
        return c.type == "city"
            and c.city   == state.currentCity
            and c.period == state.currentPeriod
    end)
    if not removed then
        return false, "no " .. state.currentCity .. "/" .. state.currentPeriod .. " card in hand"
    end
    state.playerDiscard[#state.playerDiscard + 1] = removed[1]
    state.currentCity   = destCity
    state.currentPeriod = destPeriod
    Mod.onArrive(state, {city = state.currentCity, period = state.currentPeriod})
    return true
end

function M.tryBuildOutpost(state)
    if state.outposts[state.currentCity] then
        return false, "Temporal Outpost already exists in " .. state.currentCity
    end
    if not Mod.canBuildOutpost(state, state.currentCity) then
        return false, "building blocked"
    end
    local removed = takeFromHand(state.hand, function(c)
        return c.type == "city" and c.city == state.currentCity
    end)
    if not removed then
        return false, "no card for " .. state.currentCity .. " in hand"
    end
    state.playerDiscard[#state.playerDiscard + 1] = removed[1]
    state.outposts[state.currentCity] = true
    return true
end

function M.tryClear(state, color)
    local node = state.cubes[state.currentCity][state.currentPeriod]
    if not color then
        local best, bestCount = nil, 0
        for _, c in ipairs(util.COLORS) do
            local n = node[c] or 0
            if n > bestCount then best = c; bestCount = n end
        end
        if not best then
            return false, "no anomaly cubes at " .. state.currentCity .. "/" .. state.currentPeriod
        end
        color = best
    end
    if (node[color] or 0) == 0 then
        return false, "no " .. color .. " cubes at " ..
            state.currentCity .. "/" .. state.currentPeriod
    end
    if state.resolved[color] then
        node[color] = 0
    else
        local ctx      = {city = state.currentCity, period = state.currentPeriod, color = color}
        local toRemove = Mod.cubesRemovedPerClear(state, ctx)
        node[color]    = math.max(0, node[color] - toRemove)
    end
    util.updateRepaired(state)
    return true
end

function M.tryResolve(state, color)
    if not state.outposts[state.currentCity] then
        return false, "must be at a Temporal Outpost to RESOLVE"
    end
    if state.resolved[color] then
        return false, color .. " anomaly is already RESOLVED"
    end
    local needed  = Mod.cardsToResolveAnomaly(state)
    local removed = takeFromHand(state.hand, function(c)
        return c.type == "city" and c.color == color
    end, needed)
    if not removed then
        return false, "need " .. needed .. " " .. color .. " cards in hand"
    end
    for _, c in ipairs(removed) do
        state.playerDiscard[#state.playerDiscard + 1] = c
    end
    state.resolved[color] = true
    util.updateRepaired(state)
    return true
end

function M.tryCoordinatorMove(state, destCity)
    if state.role ~= "coordinator" then
        return false, "not the Coordinator role"
    end
    if state.coordinatorMoveUsed then
        return false, "Coordinator free move already used this turn"
    end
    if not state.outposts[destCity] then
        return false, destCity .. " has no Temporal Outpost"
    end
    if destCity == state.currentCity then
        return false, "already in " .. destCity
    end
    state.currentCity        = destCity
    state.coordinatorMoveUsed = true
    Mod.onArrive(state, {city = state.currentCity, period = state.currentPeriod})
    return true
end

return M
