-- Tests for pure persistence helpers (no love.filesystem required).
local Save = require("src.persistence.save")
local H    = require("tests.helpers")

describe("Save", function()

    describe("newProfile", function()
        it("returns a table with all required fields", function()
            local p = Save.newProfile()
            assert.is_table(p)
            assert.equal(0, p.rpBalance)
            assert.is_table(p.roleUnlocks)
            assert.is_table(p.runHistory)
            assert.is_nil(p.activeRun)
            assert.is_string(p.lastRole)
        end)
    end)

    describe("serializeState", function()
        it("includes all game-state fields", function()
            local gs = H.makeState()
            gs.role                = "physicist"
            gs.coordinatorMoveUsed = false
            local s = Save.serializeState(gs)

            assert.equal(gs.currentCity,         s.currentCity)
            assert.equal(gs.currentPeriod,       s.currentPeriod)
            assert.equal(gs.instabilityIndex,    s.instabilityIndex)
            assert.equal(gs.explosionCount,      s.explosionCount)
            assert.equal(gs.actionsRemaining,    s.actionsRemaining)
            assert.equal(gs.turn,                s.turn)
            assert.equal(gs.difficulty,          s.difficulty)
            assert.equal(gs.role,                s.role)
            assert.equal(gs.coordinatorMoveUsed, s.coordinatorMoveUsed)
            assert.is_nil(s.lost)
        end)

        it("preserves cube counts", function()
            local gs = H.makeState()
            gs.cubes["atlanta"]["modern"]["blue"] = 3
            local s = Save.serializeState(gs)
            assert.equal(3, s.cubes["atlanta"]["modern"]["blue"])
        end)

        it("preserves resolved and repaired flags", function()
            local gs = H.makeState()
            gs.resolved["blue"] = true
            gs.repaired["red"]  = true
            local s = Save.serializeState(gs)
            assert.is_true(s.resolved["blue"])
            assert.is_true(s.repaired["red"])
            assert.is_false(s.resolved["yellow"])
        end)

        it("preserves outpost state", function()
            local gs = H.makeState()
            gs.outposts["atlanta"] = true
            local s = Save.serializeState(gs)
            assert.is_true(s.outposts["atlanta"])
            assert.is_nil(s.outposts["chicago"])
        end)

        it("preserves hand contents", function()
            local gs = H.makeState()
            gs.hand = {H.cityCard("seattle", "prehistory", "blue")}
            local s = Save.serializeState(gs)
            assert.equal(1, #s.hand)
            assert.equal("seattle", s.hand[1].city)
        end)

        it("serialized state can round-trip through binser", function()
            local binser = require("vendor.binser")
            local gs = H.makeState()
            gs.cubes["chicago"]["industrial"]["yellow"] = 2
            gs.outposts["new_york"] = true
            gs.role = "coordinator"

            local s    = Save.serializeState(gs)
            local data        = binser.serialize(s)
            local vals, _     = binser.deserialize(data)
            local restored    = vals[1]

            assert.equal("coordinator", restored.role)
            assert.equal(2, restored.cubes["chicago"]["industrial"]["yellow"])
            assert.is_true(restored.outposts["new_york"])
            assert.equal(gs.currentCity, restored.currentCity)
        end)
    end)

end)
