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

-- Seed threat cards (3/3/2/2/1/1 cubes). skipCount skips the first N
-- (heaviest) seedings; cube counts never reach 4 so explosion logic is skipped.
local function seedThreats(state, skipCount)
    local seedings = {3, 3, 2, 2, 1, 1}
    for i = 1 + (skipCount or 0), #seedings do
        local card = util.drawTop(state.threatDeck)
        if card then
            state.threatDiscard[#state.threatDiscard + 1] = card
            state.cubes[card.city][card.period][card.color] =
                state.cubes[card.city][card.period][card.color] + seedings[i]
        end
    end
end

function M.new(opts)
    opts = opts or {}
    local difficulty       = opts.difficulty       or "standard"
    local startCity        = opts.startCity        or "atlanta"
    local startPeriod      = opts.startPeriod      or "modern"
    local handSize         = opts.handSize         or 4
    local role             = opts.role             or "chronologist"
    local startingOutpost  = opts.startingOutpost  or false
    local skipSeedingCount = opts.skipSeedingCount or 0
    local removeFluxCount  = opts.removeFluxCount  or 0
    local extraDeckCards   = opts.extraDeckCards   or {}
    local challengeModIds  = opts.challengeModIds  or {}

    local baseDeck = buildBaseDeck()
    for _, card in ipairs(extraDeckCards) do
        baseDeck[#baseDeck + 1] = card
    end
    util.shuffle(baseDeck)

    local hand = {}
    for _ = 1, handSize do
        local card = util.drawTop(baseDeck)
        if card then hand[#hand + 1] = card end
    end

    local fluxCount  = math.max(1, (FLUX_COUNT[difficulty] or 5) - removeFluxCount)
    local threatDeck = buildThreatDeck()

    local state = {
        currentCity           = startCity,
        currentPeriod         = startPeriod,
        playerDeck            = distributeFlux(baseDeck, fluxCount),
        playerDiscard         = {},
        hand                  = hand,
        threatDeck            = threatDeck,
        threatDiscard         = {},
        cubes                 = buildCubeTable(),
        outposts              = {},
        instabilityIndex      = 1,
        explosionCount        = 0,
        actionsRemaining      = 4,
        turn                  = 1,
        phase                 = "action",
        resolved              = {blue = false, yellow = false, black = false, red = false},
        repaired              = {blue = false, yellow = false, black = false, red = false},
        difficulty            = difficulty,
        priorityCity          = nil,
        lost                  = nil,
        role                  = role,
        coordinatorMoveUsed   = false,
        challengeModIds       = challengeModIds,
        teleportBannedTurns   = 0,
        volatileAnomalyActive = false,
        hadDeckUpgrades       = #extraDeckCards > 0,
        skipNextInstability   = false,
        sealedCity            = nil,
    }

    if startingOutpost then
        state.outposts[startCity] = true
    end

    -- Seed threats before adding challenge mod cards so mods never get drawn during seeding
    seedThreats(state, skipSeedingCount)

    for _, modId in ipairs(challengeModIds) do
        state.threatDeck[#state.threatDeck + 1] = {type = "challengemod", id = modId}
    end
    if #challengeModIds > 0 then util.shuffle(state.threatDeck) end

    if difficulty == "legendary" then
        state.priorityCity = cities[math.random(#cities)].id
    end

    return state
end

return M
