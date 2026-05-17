-- Shared test helpers
local cities  = require("data.cities")
local periods = require("data.periods")

local H = {}

-- Minimal game state for unit testing rules without a full setup.
function H.makeState(overrides)
    local cubes = {}
    for _, city in ipairs(cities) do
        cubes[city.id] = {}
        for _, period in ipairs(periods) do
            cubes[city.id][period.id] = {blue = 0, yellow = 0, black = 0, red = 0}
        end
    end
    local state = {
        currentCity      = "atlanta",
        currentPeriod    = "modern",
        hand             = {},
        playerDiscard    = {},
        playerDeck       = {},
        threatDeck       = {},
        threatDiscard    = {},
        outposts         = {},
        cubes            = cubes,
        instabilityIndex = 1,
        explosionCount   = 0,
        actionsRemaining = 4,
        turn             = 1,
        phase            = "action",
        resolved         = {blue = false, yellow = false, black = false, red = false},
        repaired         = {blue = false, yellow = false, black = false, red = false},
        difficulty           = "standard",
        priorityCity         = nil,
        lost                 = nil,
        role                  = nil,
        coordinatorMoveUsed   = false,
        challengeModIds       = {},
        teleportBannedTurns   = 0,
        volatileAnomalyActive = false,
        skipNextInstability   = false,
        sealedCity            = nil,
        failsafeDesignerUsed  = false,
    }
    if overrides then
        for k, v in pairs(overrides) do state[k] = v end
    end
    return state
end

-- Quick city card constructor
function H.cityCard(cityId, periodId, color)
    return {type = "city", city = cityId, period = periodId, color = color,
            name = cityId .. "/" .. periodId}
end

-- Quick event card constructor
function H.eventCard(id)
    return {type = "event", id = id, name = id}
end

-- Quick flux card constructor
function H.fluxCard()
    return {type = "flux", id = "chronological_flux", name = "Chronological Flux"}
end

-- Quick threat card constructor
function H.threatCard(cityId, periodId, color)
    return {type = "threat", city = cityId, period = periodId, color = color,
            name = cityId .. "/" .. periodId}
end

-- Returns true if value is in a plain array table.
function H.contains(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    return false
end

return H
