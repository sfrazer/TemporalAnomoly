-- Profile persistence via binser.
-- File I/O functions use love.filesystem and must not be called outside Love2D.
-- serializeState / newProfile are pure functions and are safe to call in tests.

local binser = require("vendor.binser")

local M = {}

M.SLOT_COUNT = 3

local function profilePath(slot)
    return "profile_" .. slot .. ".dat"
end

local INDEX_PATH = "profiles.dat"

-- ---------------------------------------------------------------------------
-- Index (tracks last-used slot)
-- ---------------------------------------------------------------------------

function M.loadIndex()
    if not love.filesystem.getInfo(INDEX_PATH) then
        return {lastUsed = nil}
    end
    local data = love.filesystem.read(INDEX_PATH)
    if not data then return {lastUsed = nil} end
    local ok, result = pcall(binser.deserialize, data)
    if ok and result and result[1] then return result[1] end
    return {lastUsed = nil}
end

function M.saveIndex(index)
    love.filesystem.write(INDEX_PATH, binser.serialize(index))
end

-- ---------------------------------------------------------------------------
-- Profile slots
-- ---------------------------------------------------------------------------

function M.loadProfile(slot)
    local path = profilePath(slot)
    if not love.filesystem.getInfo(path) then return nil end
    local data = love.filesystem.read(path)
    if not data then return nil end
    local ok, result = pcall(binser.deserialize, data)
    if ok and result and result[1] then return result[1] end
    return nil
end

function M.saveProfile(slot, profile)
    love.filesystem.write(profilePath(slot), binser.serialize(profile))
end

function M.deleteProfile(slot)
    love.filesystem.remove(profilePath(slot))
end

-- ---------------------------------------------------------------------------
-- Pure helpers (safe in tests)
-- ---------------------------------------------------------------------------

function M.newProfile()
    return {
        rpBalance         = 0,
        roleUnlocks       = {},
        highestDifficulty = nil,
        runHistory        = {},
        activeRun         = nil,
        lastRole          = "chronologist",
        bonusSelections   = {},
        deckSelections    = {},
        challengeModIds   = {},
    }
end

-- Converts a live game state into a plain serializable table.
-- Does NOT include modifier handler closures — those are re-registered on load.
function M.serializeState(gs)
    return {
        currentCity          = gs.currentCity,
        currentPeriod        = gs.currentPeriod,
        cubes                = gs.cubes,
        outposts             = gs.outposts,
        hand                 = gs.hand,
        playerDeck           = gs.playerDeck,
        playerDiscard        = gs.playerDiscard,
        threatDeck           = gs.threatDeck,
        threatDiscard        = gs.threatDiscard,
        instabilityIndex     = gs.instabilityIndex,
        explosionCount       = gs.explosionCount,
        actionsRemaining     = gs.actionsRemaining,
        turn                 = gs.turn,
        resolved             = gs.resolved,
        repaired             = gs.repaired,
        difficulty           = gs.difficulty,
        priorityCity         = gs.priorityCity,
        role                 = gs.role,
        coordinatorMoveUsed  = gs.coordinatorMoveUsed,
        challengeModIds      = gs.challengeModIds,
        teleportBannedTurns  = gs.teleportBannedTurns,
        volatileAnomalyActive = gs.volatileAnomalyActive,
        lost                 = gs.lost,
    }
end

return M
