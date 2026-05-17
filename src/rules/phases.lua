local util      = require("src.util")
local flux      = require("src.rules.flux")
local explosion = require("src.rules.explosion")

local M = {}

-- Draw 2 player cards. Flux cards resolve immediately and count as a draw.
function M.runDrawPhase(state)
    for _ = 1, 2 do
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

-- Draw N threat cards (N = instability level) and place 1 cube each.
-- Skips cards whose color is REPAIRED.
function M.runInstabilityPhase(state)
    local n = util.instabilityLevel(state)
    for _ = 1, n do
        if state.lost then return end
        local card = util.drawTop(state.threatDeck)
        if card then
            state.threatDiscard[#state.threatDiscard + 1] = card
            if not state.repaired[card.color] then
                explosion.placeCubesAt(state, card.city, card.period, card.color, 1)
            end
        end
    end
end

return M
