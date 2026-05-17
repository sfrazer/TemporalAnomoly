local util    = require("src.util")
local cards   = require("data.cards")
local cities  = require("data.cities")
local periods = require("data.periods")

local FLUX_COUNT = {
    introductory = 4,
    standard     = 5,
    heroic       = 6,
    legendary    = 7,
}

local M = {}

local function buildCubeTable()
    local cubes = {}
    for _, city in ipairs(cities) do
        cubes[city.id] = {}
        for _, period in ipairs(periods) do
            cubes[city.id][period.id] = {blue = 0, yellow = 0, black = 0, red = 0}
        end
    end
    return cubes
end

-- Shuffle city+event cards only (no flux). Used to deal starting hand before
-- flux cards are distributed, matching the Pandemic dealing convention.
local function buildBaseDeck()
    local deck = {}
    for _, c in ipairs(cards.cityCards) do
        deck[#deck + 1] = {type = c.type, city = c.city, period = c.period,
                           color = c.color, name = c.name}
    end
    for _, c in ipairs(cards.eventCards) do
        deck[#deck + 1] = {type = c.type, id = c.id, name = c.name,
                           description = c.description}
    end
    return util.shuffle(deck)
end

-- Distribute n flux cards evenly through deck using standard chunk-shuffle method.
local function distributeFlux(deck, n)
    local chunkSize = math.floor(#deck / n)
    local remainder = #deck % n
    local result    = {}
    local pos       = 1
    for i = 1, n do
        local size  = chunkSize + (i <= remainder and 1 or 0)
        local chunk = {}
        for j = pos, pos + size - 1 do
            chunk[#chunk + 1] = deck[j]
        end
        pos = pos + size
        chunk[#chunk + 1] = {type = "flux", id = "chronological_flux",
                              name = "Chronological Flux"}
        util.shuffle(chunk)
        for _, card in ipairs(chunk) do
            result[#result + 1] = card
        end
    end
    return result
end

local function buildThreatDeck()
    local deck = {}
    for _, c in ipairs(cards.threatCards) do
        deck[#deck + 1] = {type = c.type, city = c.city, period = c.period,
                           color = c.color, name = c.name}
    end
    return util.shuffle(deck)
end

-- Seed 6 threat cards (3/3/2/2/1/1 cubes) directly without explosion logic;
-- cube counts never reach 4 during seeding so this is safe.
local function seedThreats(state)
    for _, n in ipairs({3, 3, 2, 2, 1, 1}) do
        local card = util.drawTop(state.threatDeck)
        if card then
            state.threatDiscard[#state.threatDiscard + 1] = card
            state.cubes[card.city][card.period][card.color] =
                state.cubes[card.city][card.period][card.color] + n
        end
    end
end

function M.new(opts)
    opts = opts or {}
    local difficulty  = opts.difficulty  or "standard"
    local startCity   = opts.startCity   or "atlanta"
    local startPeriod = opts.startPeriod or "modern"
    local handSize    = opts.handSize    or 4
    local role        = opts.role        or "chronologist"

    local baseDeck = buildBaseDeck()

    -- Deal starting hand before flux cards are mixed in
    local hand = {}
    for _ = 1, handSize do
        local card = util.drawTop(baseDeck)
        if card then hand[#hand + 1] = card end
    end

    local state = {
        currentCity      = startCity,
        currentPeriod    = startPeriod,
        playerDeck       = distributeFlux(baseDeck, FLUX_COUNT[difficulty]),
        playerDiscard    = {},
        hand             = hand,
        threatDeck       = buildThreatDeck(),
        threatDiscard    = {},
        cubes            = buildCubeTable(),
        outposts         = {},
        instabilityIndex = 1,
        explosionCount   = 0,
        actionsRemaining = 4,
        turn             = 1,
        phase            = "action",
        resolved         = {blue = false, yellow = false, black = false, red = false},
        repaired         = {blue = false, yellow = false, black = false, red = false},
        difficulty           = difficulty,
        priorityCity         = nil,
        lost                 = nil,
        role                 = role,
        coordinatorMoveUsed  = false,
    }

    seedThreats(state)

    if difficulty == "legendary" then
        state.priorityCity = cities[math.random(#cities)].id
    end

    return state
end

return M
