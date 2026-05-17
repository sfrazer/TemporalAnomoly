-- Central modifier pipeline.
--
-- Numeric hooks fold:   each handler receives (state, accumulated_value[, ctx])
--                       and returns a new value. Applied in registration order.
-- Permission hooks:     veto-AND — any handler returning false blocks the action.
-- Event hooks:          fire-all — all handlers are called; return values ignored.
--
-- Call Mod.clear() between test cases to reset all handlers.

local unpack = table.unpack or unpack  -- LuaJIT (Love2D) vs Lua 5.2+

local M = {}

local handlers = {}

function M.register(hook, fn)
    handlers[hook] = handlers[hook] or {}
    handlers[hook][#handlers[hook] + 1] = fn
end

function M.clear()
    handlers = {}
end

-- Fold: apply all handlers to accumulate a value. ctx is optional extra context.
local function fold(hook, state, base, ctx)
    local value = base
    for _, fn in ipairs(handlers[hook] or {}) do
        value = fn(state, value, ctx)
    end
    return value
end

-- Permit: returns false if any handler explicitly returns false.
local function permit(hook, state, ...)
    local args = {...}
    for _, fn in ipairs(handlers[hook] or {}) do
        if fn(state, table.unpack(args)) == false then
            return false
        end
    end
    return true
end

-- Fire: call all event handlers; return values ignored.
local function fire(hook, state, ctx)
    for _, fn in ipairs(handlers[hook] or {}) do
        fn(state, ctx)
    end
end

-- ---------------------------------------------------------------------------
-- Numeric hooks (default values = vanilla game rules)
-- ---------------------------------------------------------------------------
function M.actionsPerTurn(state)
    return fold("actionsPerTurn", state, 4)
end

function M.cardsDrawnPerTurn(state)
    return fold("cardsDrawnPerTurn", state, 2)
end

function M.cubesPerThreatCard(state)
    return fold("cubesPerThreatCard", state, 1)
end

function M.cardsToResolveAnomaly(state)
    return fold("cardsToResolveAnomaly", state, 5)
end

-- ctx = {city, period, color} of the node being cleared
function M.cubesRemovedPerClear(state, ctx)
    return fold("cubesRemovedPerClear", state, 1, ctx)
end

-- ---------------------------------------------------------------------------
-- Permission hooks (return true unless a handler vetoes)
-- ---------------------------------------------------------------------------

-- from/to are {city, period} tables
function M.canTravel(state, from, to)
    return permit("canTravel", state, from, to)
end

function M.canBuildOutpost(state, city)
    return permit("canBuildOutpost", state, city)
end

function M.canPlaceCube(state, city, period, color)
    return permit("canPlaceCube", state, city, period, color)
end

-- ---------------------------------------------------------------------------
-- Event hooks (fire-all, no return value)
-- ---------------------------------------------------------------------------
function M.onThreatCardDraw(state, ctx)
    fire("onThreatCardDraw", state, ctx)
end

function M.onChronologicalFlux(state, ctx)
    fire("onChronologicalFlux", state, ctx)
end

function M.onTemporalExplosion(state, ctx)
    fire("onTemporalExplosion", state, ctx)
end

-- ctx = {city, period, color} — fired after a single cube is successfully placed.
function M.onCubePlaced(state, ctx)
    fire("onCubePlaced", state, ctx)
end

function M.onArrive(state, ctx)
    fire("onArrive", state, ctx)
end

return M
