local util      = require("src.util")
local explosion = require("src.rules.explosion")

local M = {}

function M.resolveChronologicalFlux(state)
    -- 1. Advance instability index (cap at 7)
    if state.instabilityIndex < 7 then
        state.instabilityIndex = state.instabilityIndex + 1
    end

    -- 2. Draw bottom card of threat deck -> place 3 cubes
    local card = util.drawBottom(state.threatDeck)
    if card then
        state.threatDiscard[#state.threatDiscard + 1] = card
        if not state.repaired[card.color] then
            explosion.placeCubesAt(state, card.city, card.period, card.color, 3)
        end
    end

    -- 3. Shuffle threat discard (including just-drawn card) -> prepend to threat deck
    local reshuffled = {}
    for _, c in ipairs(state.threatDiscard) do reshuffled[#reshuffled + 1] = c end
    state.threatDiscard = {}
    util.shuffle(reshuffled)
    for i = #reshuffled, 1, -1 do
        table.insert(state.threatDeck, 1, reshuffled[i])
    end
end

return M
