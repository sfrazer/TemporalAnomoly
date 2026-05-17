-- Autosave trigger module.
-- Call M.init(slot, profile) when a run starts.
-- Call M.save(gs) after every action and phase transition.
-- Call M.finish() when a run ends (win or loss) to clear the active run.

local Save = require("src.persistence.save")

local M = {}

local _slot    = nil
local _profile = nil

function M.init(slot, profile)
    _slot    = slot
    _profile = profile
end

function M.getSlot()    return _slot    end
function M.getProfile() return _profile end

function M.save(gs)
    if not _slot or not _profile or not gs then return end
    _profile.activeRun = Save.serializeState(gs)
    _profile.lastRole  = gs.role
    Save.saveProfile(_slot, _profile)
    Save.saveIndex({lastUsed = _slot})
end

function M.finish()
    if not _slot or not _profile then return end
    _profile.activeRun = nil
    Save.saveProfile(_slot, _profile)
    _slot    = nil
    _profile = nil
end

return M
