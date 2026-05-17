local util      = require("src.util")
local Mod       = require("src.state.modifiers")
local explosion = require("src.rules.explosion")

local M = {}

function M.resolveChronologicalFlux(state)
    if state.instabilityIndex < 7 then
        state.instabilityIndex = state.instabilityIndex + 1
    end

    local citiesToSeed = 1
    if state.volatileAnomalyActive then
        citiesToSeed = 3
        state.volatileAnomalyActive = false
    end

    for _ = 1, citiesToSeed do
        local card = util.drawBottom(state.threatDeck)
        if card then
            state.threatDiscard[#state.threatDiscard + 1] = card
            Mod.onChronologicalFlux(state, {card = card})
            if card.type == "threat" and not state.repaired[card.color] then
                explosion.placeCubesAt(state, card.city, card.period, card.color, 3)
            end
        end
    end

    local reshuffled = {}
    for _, c in ipairs(state.threatDiscard) do reshuffled[#reshuffled + 1] = c end
    state.threatDiscard = {}
    util.shuffle(reshuffled)
    for i = #reshuffled, 1, -1 do
        table.insert(state.threatDeck, 1, reshuffled[i])
    end
end

return M
