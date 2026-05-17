local util    = require("src.util")
local cities  = require("data.cities")
local periods = require("data.periods")

local cityById = {}
for _, c in ipairs(cities) do cityById[c.id] = c end

local PERIOD_IDS = {}
for _, p in ipairs(periods) do PERIOD_IDS[#PERIOD_IDS + 1] = p.id end

local M = {}

-- Forward declaration
local tryPlaceCubeWithExplosion

-- visited keys are "cityId:periodId:color" of nodes currently mid-explosion.
tryPlaceCubeWithExplosion = function(state, cityId, periodId, color, visited)
    if state.lost then return end
    local node = state.cubes[cityId][periodId]
    if node[color] >= 3 then
        -- Would be 4th cube: chain-explode instead of placing.
        M.resolveTemporalExplosion(state, cityId, periodId, color, visited)
    else
        if util.cubeSupply(state, color) <= 0 then
            state.lost = "anomaly supply exhausted (" .. color .. ")"
            return
        end
        node[color] = node[color] + 1
    end
end

function M.resolveTemporalExplosion(state, cityId, periodId, color, visited)
    visited = visited or {}
    local key = cityId .. ":" .. periodId .. ":" .. color
    if visited[key] then return end  -- already exploding this round
    visited[key] = true

    state.explosionCount = state.explosionCount + 1

    if state.difficulty == "legendary" and cityId == state.priorityCity then
        state.lost = "priority city exploded"
    end

    -- Spread to same-period neighbors
    for _, nid in ipairs(cityById[cityId].adjacent) do
        tryPlaceCubeWithExplosion(state, nid, periodId, color, visited)
    end

    -- Spread to other periods when this city has a Temporal Outpost
    if state.outposts[cityId] then
        for _, pid in ipairs(PERIOD_IDS) do
            if pid ~= periodId then
                tryPlaceCubeWithExplosion(state, cityId, pid, color, visited)
            end
        end
    end
end

-- Public entry point: place n cubes of color at a node, handling explosions.
-- Each cube placement is independent (fresh visited per cube).
function M.placeCubesAt(state, cityId, periodId, color, n)
    for _ = 1, (n or 1) do
        if state.lost then return end
        tryPlaceCubeWithExplosion(state, cityId, periodId, color, {})
    end
end

return M
