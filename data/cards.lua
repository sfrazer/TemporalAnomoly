local cities  = require("data.cities")
local periods = require("data.periods")

local M = {}

-- 48 city cards: 2 copies per (city, period) pair
M.cityCards = {}
for _, city in ipairs(cities) do
    for _, period in ipairs(periods) do
        for _ = 1, 2 do
            M.cityCards[#M.cityCards + 1] = {
                type   = "city",
                city   = city.id,
                period = period.id,
                color  = period.color,
                name   = city.name .. " (" .. period.name .. ")",
            }
        end
    end
end

-- 4 base event cards (always shuffled into the player deck)
M.eventCards = {
    {
        type        = "event",
        id          = "paradox_barrier",
        name        = "Paradox Barrier",
        description = "Skip the next Instability Phase.",
    },
    {
        type        = "event",
        id          = "unknown_assistance",
        name        = "Unknown Assistance",
        description = "Place a Temporal Outpost in any city; no discard required.",
    },
    {
        type        = "event",
        id          = "temporal_slip",
        name        = "Temporal Slip",
        description = "Move to any (city, period) for free.",
    },
    {
        type        = "event",
        id          = "chrono_lock",
        name        = "Chrono Lock",
        description = "Remove 1 card from the threat discard so it does not return on reshuffle.",
    },
}

-- Chronological Flux card template; N copies are shuffled in at run setup per difficulty
M.fluxCard = {
    type = "flux",
    id   = "chronological_flux",
    name = "Chronological Flux",
}

-- 24 threat cards: 1 per (city, period) pair
M.threatCards = {}
for _, city in ipairs(cities) do
    for _, period in ipairs(periods) do
        M.threatCards[#M.threatCards + 1] = {
            type   = "threat",
            city   = city.id,
            period = period.id,
            color  = period.color,
            name   = city.name .. " (" .. period.name .. ")",
        }
    end
end

return M
