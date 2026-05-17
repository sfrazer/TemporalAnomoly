local util      = require("src.util")
local cities    = require("data.cities")
local periods   = require("data.periods")

local cityById = {}
for _, c in ipairs(cities) do cityById[c.id] = c end

local PERIOD_IDS = {}
for _, p in ipairs(periods) do PERIOD_IDS[#PERIOD_IDS + 1] = p.id end

local M = {}

-- Remove up to n cards matching pred from hand; returns array of removed cards
-- or false if fewer than n matched.
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

-- Travel: adjacent city same period, OR same city different period via Outpost.
function M.tryTravel(state, destCity, destPeriod)
    destPeriod = destPeriod or state.currentPeriod

    if destCity == state.currentCity and destPeriod == state.currentPeriod then
        return false, "already at destination"
    end

    -- Cross-period (same city): requires Outpost
    if destCity == state.currentCity then
        if not state.outposts[state.currentCity] then
            return false, "no Temporal Outpost in " .. state.currentCity
        end
        state.currentPeriod = destPeriod
        return true
    end

    -- Same-period: destination must be adjacent; period must match
    if destPeriod ~= state.currentPeriod then
        return false, "cannot change both city and period in one Travel action"
    end

    for _, nid in ipairs(cityById[state.currentCity].adjacent) do
        if nid == destCity then
            state.currentCity = destCity
            return true
        end
    end

    return false, destCity .. " is not adjacent to " .. state.currentCity
end

-- Teleport: discard a (city, period) card -> move to that city/period.
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
    return true
end

-- Teleport (alternate): discard current location card -> move anywhere.
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
    return true
end

-- Build Temporal Outpost: discard any card for current city -> outpost in all periods.
function M.tryBuildOutpost(state)
    if state.outposts[state.currentCity] then
        return false, "Temporal Outpost already exists in " .. state.currentCity
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

-- Clear Anomalous Incident: remove 1 cube (or all if anomaly RESOLVED).
function M.tryClear(state, color)
    local node = state.cubes[state.currentCity][state.currentPeriod]
    if (node[color] or 0) == 0 then
        return false, "no " .. color .. " cubes at " ..
            state.currentCity .. "/" .. state.currentPeriod
    end
    if state.resolved[color] then
        node[color] = 0
    else
        node[color] = node[color] - 1
    end
    util.updateRepaired(state)
    return true
end

-- RESOLVE Anomaly: at Outpost, discard 5 same-color cards.
function M.tryResolve(state, color)
    if not state.outposts[state.currentCity] then
        return false, "must be at a Temporal Outpost to RESOLVE"
    end
    if state.resolved[color] then
        return false, color .. " anomaly is already RESOLVED"
    end
    local removed = takeFromHand(state.hand, function(c)
        return c.type == "city" and c.color == color
    end, 5)
    if not removed then
        return false, "need 5 " .. color .. " cards in hand"
    end
    for _, c in ipairs(removed) do
        state.playerDiscard[#state.playerDiscard + 1] = c
    end
    state.resolved[color] = true
    util.updateRepaired(state)
    return true
end

return M
