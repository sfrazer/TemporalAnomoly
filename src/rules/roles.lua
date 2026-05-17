local Mod    = require("src.state.modifiers")
local util   = require("src.util")
local cities = require("data.cities")

local M = {}

-- Adjacency lookup built once at module load: adjacentTo[cityId][neighborId] = true
local adjacentTo = {}
for _, city in ipairs(cities) do
    adjacentTo[city.id] = {}
    for _, nid in ipairs(city.adjacent) do
        adjacentTo[city.id][nid] = true
    end
end

local APPLY = {}

APPLY.chronologist = function()
    -- Clear removes all cubes of chosen color (not just 1)
    Mod.register("cubesRemovedPerClear", function(state, value, ctx)
        return 99
    end)
    -- Auto-clear RESOLVED anomaly cubes whenever the player arrives at a node.
    -- Checks resolved (not repaired) because repaired requires 0 cubes — the
    -- auto-clear is exactly what moves an anomaly from RESOLVED toward REPAIRED.
    Mod.register("onArrive", function(state, ctx)
        local node = state.cubes[state.currentCity][state.currentPeriod]
        for _, color in ipairs(util.COLORS) do
            if state.resolved[color] and (node[color] or 0) > 0 then
                node[color] = 0
            end
        end
        util.updateRepaired(state)
    end)
end

APPLY.physicist = function()
    -- Reduce cards needed to resolve an anomaly by 1 (4 instead of 5)
    Mod.register("cardsToResolveAnomaly", function(state, value)
        return value - 1
    end)
end

APPLY.coordinator = function()
    -- Free move handled via state.coordinatorMoveUsed; no modifier hooks needed
end

APPLY.temporal_isolationist = function(state)
    Mod.register("canPlaceCube", function(s, city, period, color)
        if city == s.currentCity then return false end
        if adjacentTo[s.currentCity] and adjacentTo[s.currentCity][city] then return false end
    end)
end

APPLY.engineer = function(state)
    Mod.register("outpostCardRequired", function(s, value)
        return false
    end)
end

APPLY.researcher = function(state)
    -- +1 card drawn into hand from deck
    local card = util.drawTop(state.playerDeck)
    if card then state.hand[#state.hand + 1] = card end
    -- Insert a free Chronological Rewind at a random deck position
    local rewind = {
        type        = "event",
        id          = "chronological_rewind",
        name        = "Chronological Rewind",
        description = "Clear all cubes of 1 color across all periods of current city",
    }
    local pos = math.random(#state.playerDeck + 1)
    table.insert(state.playerDeck, pos, rewind)
end

APPLY.failsafe_designer = function(state)
    -- Ability is UI-triggered (Retrieve Card button); no passive modifiers
end

APPLY.temporal_analyst = function(state)
    -- Ability is UI-triggered (Peek Threat button); no passive modifiers
end

function M.applyRole(state, roleId)
    local fn = APPLY[roleId]
    if fn then fn(state) end
end

return M
