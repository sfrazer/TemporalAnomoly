local Unlocks = require("src.rules.unlocks")
local H       = require("tests.helpers")

local function makeProfile(overrides)
    local p = {roleUnlocks = {}}
    if overrides then for k, v in pairs(overrides) do p[k] = v end end
    return p
end

local function wonAt(difficulty, opts)
    local gs = H.makeState({difficulty = difficulty})
    if opts then for k, v in pairs(opts) do gs[k] = v end end
    gs.lost = nil  -- won
    return gs
end

describe("Unlocks", function()

    -- -------------------------------------------------------------------------
    describe("evaluateUnlocks", function()

        -- temporal_isolationist (standard+)
        it("temporal_isolationist: win at standard unlocks it", function()
            local gs = wonAt("standard")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "temporal_isolationist" then found = true end end
            assert.is_true(found)
        end)

        it("temporal_isolationist: win at introductory does NOT unlock it", function()
            local gs = wonAt("introductory")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "temporal_isolationist" then found = true end end
            assert.is_false(found)
        end)

        it("temporal_isolationist: already unlocked is not returned again", function()
            local gs = wonAt("standard")
            local profile = makeProfile({roleUnlocks = {temporal_isolationist = true}})
            local newly = Unlocks.evaluateUnlocks(gs, profile)
            local found = false
            for _, id in ipairs(newly) do if id == "temporal_isolationist" then found = true end end
            assert.is_false(found)
        end)

        -- engineer (heroic+)
        it("engineer: win at heroic unlocks it", function()
            local gs = wonAt("heroic")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "engineer" then found = true end end
            assert.is_true(found)
        end)

        it("engineer: win at standard does NOT unlock it", function()
            local gs = wonAt("standard")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "engineer" then found = true end end
            assert.is_false(found)
        end)

        -- researcher (heroic+)
        it("researcher: win at heroic unlocks it", function()
            local gs = wonAt("heroic")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "researcher" then found = true end end
            assert.is_true(found)
        end)

        -- failsafe_designer (legendary only)
        it("failsafe_designer: win at legendary unlocks it", function()
            local gs = wonAt("legendary")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "failsafe_designer" then found = true end end
            assert.is_true(found)
        end)

        it("failsafe_designer: win at heroic does NOT unlock it", function()
            local gs = wonAt("heroic")
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "failsafe_designer" then found = true end end
            assert.is_false(found)
        end)

        -- temporal_analyst (0 deck upgrades)
        it("temporal_analyst: win with no deck upgrades unlocks it", function()
            local gs = wonAt("standard", {hadDeckUpgrades = false})
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "temporal_analyst" then found = true end end
            assert.is_true(found)
        end)

        it("temporal_analyst: win with deck upgrades does NOT unlock it", function()
            local gs = wonAt("standard", {hadDeckUpgrades = true})
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "temporal_analyst" then found = true end end
            assert.is_false(found)
        end)

        -- chronomancer (heroic+ with 0 teleports)
        it("chronomancer: heroic win with 0 teleports unlocks it", function()
            local gs = wonAt("heroic", {teleportsUsed = 0})
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "chronomancer" then found = true end end
            assert.is_true(found)
        end)

        it("chronomancer: heroic win with teleports used does NOT unlock it", function()
            local gs = wonAt("heroic", {teleportsUsed = 3})
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "chronomancer" then found = true end end
            assert.is_false(found)
        end)

        it("chronomancer: standard win does NOT unlock it even with 0 teleports", function()
            local gs = wonAt("standard", {teleportsUsed = 0})
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            local found = false
            for _, id in ipairs(newly) do if id == "chronomancer" then found = true end end
            assert.is_false(found)
        end)

        it("legendary win unlocks multiple roles at once", function()
            local gs = wonAt("legendary", {hadDeckUpgrades = false, teleportsUsed = 0})
            local newly = Unlocks.evaluateUnlocks(gs, makeProfile())
            -- temporal_isolationist, engineer, researcher, failsafe_designer,
            -- temporal_analyst, chronomancer
            assert.is_true(#newly >= 6)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("applyUnlocks", function()
        it("adds ids to profile.roleUnlocks", function()
            local profile = makeProfile()
            Unlocks.applyUnlocks(profile, {"engineer", "researcher"})
            assert.is_true(profile.roleUnlocks.engineer)
            assert.is_true(profile.roleUnlocks.researcher)
        end)

        it("creates roleUnlocks table if missing", function()
            local profile = {}
            Unlocks.applyUnlocks(profile, {"engineer"})
            assert.is_true(profile.roleUnlocks.engineer)
        end)

        it("does not overwrite existing unlocks", function()
            local profile = makeProfile({roleUnlocks = {temporal_isolationist = true}})
            Unlocks.applyUnlocks(profile, {"engineer"})
            assert.is_true(profile.roleUnlocks.temporal_isolationist)
            assert.is_true(profile.roleUnlocks.engineer)
        end)
    end)

end)
