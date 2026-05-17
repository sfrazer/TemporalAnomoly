local explosion = require("src.rules.explosion")
local H         = require("tests.helpers")

describe("src.rules.explosion", function()
    local state

    before_each(function()
        state = H.makeState()
    end)

    -- -----------------------------------------------------------------------
    describe("placeCubesAt (no explosion)", function()
        it("places a cube on an empty node", function()
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            assert.equal(1, state.cubes["atlanta"]["modern"]["black"])
        end)

        it("places multiple cubes", function()
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 3)
            assert.equal(3, state.cubes["atlanta"]["modern"]["black"])
        end)

        it("triggers supply-exhausted loss when supply = 0", function()
            -- Fill up 24 black cubes across board
            state.cubes["atlanta"]["modern"]["black"]     = 3
            state.cubes["houston"]["modern"]["black"]     = 3
            state.cubes["chicago"]["modern"]["black"]     = 3
            state.cubes["new_york"]["modern"]["black"]    = 3
            state.cubes["seattle"]["modern"]["black"]     = 3
            state.cubes["los_angeles"]["modern"]["black"] = 3
            -- 18 so far, 6 remaining periods per city * more...
            -- Just set individual period nodes to exhaust supply
            state.cubes["atlanta"]["prehistory"]["black"]  = 2
            state.cubes["houston"]["prehistory"]["black"]  = 2
            state.cubes["chicago"]["prehistory"]["black"]  = 2
            -- Total: 18 + 6 = 24 -> supply = 0
            explosion.placeCubesAt(state, "new_york", "prehistory", "black", 1)
            assert.not_nil(state.lost)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("resolveTemporalExplosion", function()
        it("increments explosion counter", function()
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            assert.equal(1, state.explosionCount)
        end)

        it("spreads 1 cube to each same-period neighbor", function()
            -- atlanta modern is adjacent to houston and new_york
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            assert.equal(1, state.cubes["houston"]["modern"]["black"])
            assert.equal(1, state.cubes["new_york"]["modern"]["black"])
        end)

        it("does not place a 4th cube on the exploding node", function()
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            assert.equal(3, state.cubes["atlanta"]["modern"]["black"])
        end)

        it("chains when a neighbor also has 3 cubes", function()
            state.cubes["atlanta"]["modern"]["black"] = 3
            state.cubes["houston"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            -- atlanta explodes -> houston (3 cubes) also explodes
            assert.is_true(state.explosionCount >= 2)
        end)

        it("does not back-explode to the original node in a chain", function()
            state.cubes["atlanta"]["modern"]["black"] = 3
            state.cubes["houston"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            -- Atlanta should NOT receive a second explosion from houston
            assert.equal(3, state.cubes["atlanta"]["modern"]["black"])
        end)

        it("spreads to other periods when outpost is present", function()
            state.outposts["atlanta"] = true
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            -- Should spread black cubes to atlanta in other 3 periods
            local cross = state.cubes["atlanta"]["prehistory"]["black"]
                        + state.cubes["atlanta"]["industrial"]["black"]
                        + state.cubes["atlanta"]["far_future"]["black"]
            assert.equal(3, cross)
        end)

        it("does not spread to other periods without outpost", function()
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            local cross = state.cubes["atlanta"]["prehistory"]["black"]
                        + state.cubes["atlanta"]["industrial"]["black"]
                        + state.cubes["atlanta"]["far_future"]["black"]
            assert.equal(0, cross)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("legendary priority city", function()
        it("sets state.lost when priority city explodes", function()
            state.difficulty    = "legendary"
            state.priorityCity  = "atlanta"
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            assert.not_nil(state.lost)
            assert.truthy(state.lost:find("priority city"))
        end)

        it("does not set state.lost for non-priority city", function()
            state.difficulty   = "legendary"
            state.priorityCity = "chicago"
            state.cubes["atlanta"]["modern"]["black"] = 3
            explosion.placeCubesAt(state, "atlanta", "modern", "black", 1)
            assert.is_nil(state.lost)
        end)
    end)
end)
