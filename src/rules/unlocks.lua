local M = {}

local DIFFICULTY_TIER = {introductory = 0, standard = 1, heroic = 2, legendary = 3}

local CONDITIONS = {
    temporal_isolationist = function(gs)
        return (DIFFICULTY_TIER[gs.difficulty] or 0) >= 1
    end,
    engineer = function(gs)
        return (DIFFICULTY_TIER[gs.difficulty] or 0) >= 2
    end,
    researcher = function(gs)
        return (DIFFICULTY_TIER[gs.difficulty] or 0) >= 2
    end,
    failsafe_designer = function(gs)
        return (DIFFICULTY_TIER[gs.difficulty] or 0) >= 3
    end,
    temporal_analyst = function(gs)
        return not gs.hadDeckUpgrades
    end,
}

-- Returns list of newly unlocked role IDs. Only call when the player won.
function M.evaluateUnlocks(gs, profile)
    local existing = profile.roleUnlocks or {}
    local newly = {}
    for roleId, check in pairs(CONDITIONS) do
        if not existing[roleId] then
            if check(gs) then
                newly[#newly + 1] = roleId
            end
        end
    end
    return newly
end

-- Mutates profile.roleUnlocks with newly unlocked ids.
function M.applyUnlocks(profile, newlyUnlocked)
    profile.roleUnlocks = profile.roleUnlocks or {}
    for _, roleId in ipairs(newlyUnlocked) do
        profile.roleUnlocks[roleId] = true
    end
end

return M
