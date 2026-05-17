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
    if (state.teleportBannedTurns or 0) > 0 then
        return false, "Teleport actions disabled (Temporal Ban)"
    end
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
    if (state.teleportBannedTurns or 0) > 0 then
        return false, "Teleport actions disabled (Temporal Ban)"
    end
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
    if Mod.outpostCardRequired(state) then
        local removed = takeFromHand(state.hand, function(c)
            return c.type == "city" and c.city == state.currentCity
        end)
        if not removed then
            return false, "no card for " .. state.currentCity .. " in hand"
        end
        state.playerDiscard[#state.playerDiscard + 1] = removed[1]
    end
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

-- ---------------------------------------------------------------------------
-- Card play helpers
-- ---------------------------------------------------------------------------

local function discardCard(state, cardIdx, card)
    table.remove(state.hand, cardIdx)
    state.playerDiscard[#state.playerDiscard + 1] = card
end

function M.playParadoxBarrier(state)
    state.skipNextInstability = true
    return true
end

function M.playUnknownAssistance(state, cityId)
    if state.outposts[cityId] then
        return false, "Temporal Outpost already exists there"
    end
    state.outposts[cityId] = true
    return true
end

function M.playTemporalSlip(state, cityId, periodId)
    state.currentCity   = cityId
    state.currentPeriod = periodId
    Mod.onArrive(state, {city = cityId, period = periodId})
    return true
end

function M.playChronoLock(state, threatIdx)
    if #state.threatDiscard == 0 then
        return false, "Threat discard is empty"
    end
    table.remove(state.threatDiscard, threatIdx)
    return true
end

function M.playChronologicalRewind(state, color)
    local cityId = state.currentCity
    for _, pid in ipairs(PERIOD_IDS) do
        state.cubes[cityId][pid][color] = 0
    end
    util.updateRepaired(state)
    return true
end

function M.playTimeCorridor(state)
    state.actionsRemaining = state.actionsRemaining + 2
    return true
end

function M.playTemporalSeal(state, cityId)
    state.sealedCity = cityId
    return true
end

function M.playMobileOutpost(state)
    return false, "Not yet implemented"
end

function M.playSupplyDrop(state)
    return false, "Not yet implemented"
end

-- Routes a card play by card.id. For cards needing modal input, arg1/arg2
-- are the already-resolved choices passed by main.lua after modal resolution.
-- Returns (ok, err); on success, card is spliced from hand and moved to discard.
function M.tryPlayCard(state, cardIdx, arg1, arg2)
    local card = state.hand[cardIdx]
    if not card then return false, "invalid card index" end

    local ok, err
    local id = card.id

    if id == "paradox_barrier" then
        ok, err = M.playParadoxBarrier(state)
    elseif id == "unknown_assistance" then
        ok, err = M.playUnknownAssistance(state, arg1)
    elseif id == "temporal_slip" then
        ok, err = M.playTemporalSlip(state, arg1, arg2)
    elseif id == "chrono_lock" then
        ok, err = M.playChronoLock(state, arg1)
    elseif id == "chronological_rewind" then
        ok, err = M.playChronologicalRewind(state, arg1)
    elseif id == "mobile_outpost" then
        ok, err = M.playMobileOutpost(state)
    elseif id == "time_corridor" then
        ok, err = M.playTimeCorridor(state)
    elseif id == "temporal_seal" then
        ok, err = M.playTemporalSeal(state, arg1)
    elseif id == "supply_drop" then
        ok, err = M.playSupplyDrop(state)
    else
        return false, "no effect for card: " .. (id or "?")
    end

    if ok then discardCard(state, cardIdx, card) end
    return ok, err
end

function M.tryRetrieveCard(state, discardIdx)
    if state.failsafeDesignerUsed then
        return false, "Retrieve Card already used this run"
    end
    local card = state.playerDiscard[discardIdx]
    if not card or card.type ~= "event" then
        return false, "not a valid event card"
    end
    table.remove(state.playerDiscard, discardIdx)
    state.hand[#state.hand + 1] = card
    state.failsafeDesignerUsed = true
    return true
end

-- Pure read: returns a list of movement verbs available for reaching (destCity, destPeriod).
-- Subset of {"travel", "teleport", "teleport_alt"}. Does not mutate state.
function M.movementOptions(state, destCity, destPeriod)
    if destCity == state.currentCity and destPeriod == state.currentPeriod then
        return {}
    end
    local banned = (state.teleportBannedTurns or 0) > 0
    local opts   = {}

    -- Travel: adjacent same-period, or same-city cross-period via Outpost
    if Mod.canTravel(state, {city = state.currentCity, period = state.currentPeriod},
                            {city = destCity,          period = destPeriod}) then
        if destCity == state.currentCity then
            if state.outposts[state.currentCity] then opts[#opts+1] = "travel" end
        elseif destPeriod == state.currentPeriod then
            local c = cityById[state.currentCity]
            if c then
                for _, nid in ipairs(c.adjacent) do
                    if nid == destCity then opts[#opts+1] = "travel"; break end
                end
            end
        end
    end

    if not banned then
        -- Teleport: card in hand matching destination
        for _, c in ipairs(state.hand) do
            if c.type == "city" and c.city == destCity and c.period == destPeriod then
                opts[#opts+1] = "teleport"; break
            end
        end
        -- Teleport Alt: card in hand matching current location
        for _, c in ipairs(state.hand) do
            if c.type == "city" and c.city == state.currentCity and c.period == state.currentPeriod then
                opts[#opts+1] = "teleport_alt"; break
            end
        end
    end

    return opts
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
