local util = require("src.util")
local shop = require("data.shop")
local Mod  = require("src.state.modifiers")

local M = {}

local DIFF_TIER = {introductory = 0, standard = 1, heroic = 2, legendary = 3}

-- RP earned at end of a run.
function M.computeRP(gs, challengeModIds)
    local rp = 1  -- +1 for attempting
    for _, color in ipairs(util.COLORS) do
        if gs.repaired[color] then rp = rp + 2 end
    end
    if not gs.lost then rp = rp + 3 end
    rp = rp + (DIFF_TIER[gs.difficulty] or 0)
    for _, modId in ipairs(challengeModIds or {}) do
        for _, mod in ipairs(shop.challengeMods) do
            if mod.id == modId then rp = rp + mod.bonusRP; break end
        end
    end
    return rp
end

-- Total RP cost of the current bonus + deck selections.
-- Challenge mods are free.
function M.totalCost(bonusSelections, deckSelections)
    local total = 0
    for _, item in ipairs(shop.startingBonuses) do
        total = total + item.cost * (bonusSelections[item.id] or 0)
    end
    for _, item in ipairs(shop.deckCards) do
        total = total + item.cost * (deckSelections[item.id] or 0)
    end
    return total
end

-- Convert profile selections into opts table for GameState.new().
function M.prepOpts(profile, roleId)
    local bs = profile.bonusSelections or {}
    local ds = profile.deckSelections  or {}
    local cm = profile.challengeModIds or {}

    local extraDeckCards = {}
    for _, item in ipairs(shop.deckCards) do
        local count = ds[item.id] or 0
        for _ = 1, count do
            extraDeckCards[#extraDeckCards + 1] = {
                type        = "event",
                id          = item.id,
                name        = item.name,
                description = item.description,
            }
        end
    end

    local challengeModIds = {}
    for _, id in ipairs(cm) do
        challengeModIds[#challengeModIds + 1] = id
    end

    return {
        role             = roleId,
        handSize         = 4 + (bs.extra_starting_card or 0),
        startingOutpost  = (bs.starting_outpost or 0) > 0,
        skipSeedingCount = (bs.light_incidents  or 0) > 0 and 2 or 0,
        removeFluxCount  = bs.remove_flux or 0,
        bonusActions     = (bs.bonus_action or 0) > 0 and 1 or 0,
        extraDeckCards   = extraDeckCards,
        challengeModIds  = challengeModIds,
    }
end

-- Register meta-upgrade modifier hooks onto the pipeline.
-- Call after Mod.clear() and Roles.applyRole().
function M.applyModifiers(opts)
    if (opts.bonusActions or 0) > 0 then
        Mod.register("actionsPerTurn", function(state, value)
            return value + opts.bonusActions
        end)
    end
end

return M
