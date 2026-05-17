local Mod  = require("src.state.modifiers")
local util = require("src.util")

local M = {}

local APPLY = {}

APPLY.chronologist = function()
    -- Clear removes all cubes of chosen color (not just 1)
    Mod.register("cubesRemovedPerClear", function(state, value, ctx)
        return 99
    end)
    -- Auto-clear REPAIRED anomaly cubes whenever the player arrives at a node
    Mod.register("onArrive", function(state, ctx)
        local node = state.cubes[state.currentCity][state.currentPeriod]
        for _, color in ipairs(util.COLORS) do
            if state.repaired[color] and (node[color] or 0) > 0 then
                node[color] = 0
            end
        end
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

function M.applyRole(state, roleId)
    local fn = APPLY[roleId]
    if fn then fn() end
end

return M
