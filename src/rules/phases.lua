local util      = require("src.util")
local Mod       = require("src.state.modifiers")
local flux      = require("src.rules.flux")
local explosion = require("src.rules.explosion")
local cities    = require("data.cities")
local periods   = require("data.periods")

local M = {}

function M.applyChallengeModEffect(state, card)
    if card.id == "hotspot" then
        local valid = {}
        for _, c in ipairs(cities) do
            for _, p in ipairs(periods) do
                if not state.repaired[p.color] then
                    valid[#valid + 1] = {city = c.id, period = p.id, color = p.color}
                end
            end
        end
        if #valid > 0 then
            local s = valid[math.random(#valid)]
            explosion.placeCubesAt(state, s.city, s.period, s.color, 2)
        end

    elseif card.id == "cascade_event" then
        for _ = 1, 2 do
            local extra = util.drawTop(state.threatDeck)
            if extra then
                state.threatDiscard[#state.threatDiscard + 1] = extra
                if extra.type == "threat" and not state.repaired[extra.color] then
                    local cubes = Mod.cubesPerThreatCard(state)
                    explosion.placeCubesAt(state, extra.city, extra.period, extra.color, cubes)
                end
            end
        end

    elseif card.id == "volatile_anomaly" then
        state.volatileAnomalyActive = true

    elseif card.id == "temporal_ban" then
        state.teleportBannedTurns = (state.teleportBannedTurns or 0) + 1
    end
end

-- Draws N threat cards from the deck into threatDiscard and returns them as
-- step descriptors {card, stepType} without placing any cubes.
-- Caller executes each step one at a time for the instability animation.
function M.buildInstabilitySteps(state)
    if state.skipNextInstability then
        state.skipNextInstability = false
        return {}
    end
    local n     = util.instabilityLevel(state)
    local steps = {}
    for _ = 1, n do
        local card = util.drawTop(state.threatDeck)
        if card then
            state.threatDiscard[#state.threatDiscard + 1] = card
            steps[#steps + 1] = {
                card     = card,
                stepType = card.type == "challengemod" and "challengemod" or "threat",
            }
        end
    end
    return steps
end

function M.runDrawPhase(state)
    local n = Mod.cardsDrawnPerTurn(state)
    for _ = 1, n do
        if #state.playerDeck == 0 then
            state.lost = "player deck exhausted"
            return
        end
        local card = util.drawTop(state.playerDeck)
        if card.type == "flux" then
            state.playerDiscard[#state.playerDiscard + 1] = card
            flux.resolveChronologicalFlux(state)
        else
            state.hand[#state.hand + 1] = card
        end
        if state.lost then return end
    end
end

function M.runInstabilityPhase(state)
    if state.skipNextInstability then
        state.skipNextInstability = false
        return
    end
    local n = util.instabilityLevel(state)
    for _ = 1, n do
        if state.lost then return end
        local card = util.drawTop(state.threatDeck)
        if card then
            state.threatDiscard[#state.threatDiscard + 1] = card
            if card.type == "challengemod" then
                M.applyChallengeModEffect(state, card)
            else
                Mod.onThreatCardDraw(state, {card = card})
                if not state.repaired[card.color] then
                    local cubes = Mod.cubesPerThreatCard(state)
                    explosion.placeCubesAt(state, card.city, card.period, card.color, cubes)
                end
            end
        end
    end
end

return M
