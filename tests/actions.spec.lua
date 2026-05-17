local actions = require("src.rules.actions")
local H       = require("tests.helpers")

describe("src.rules.actions", function()
    local state

    before_each(function()
        state = H.makeState()  -- starts at atlanta/modern
    end)

    -- -----------------------------------------------------------------------
    describe("tryTravel", function()
        it("moves to an adjacent city in the same period", function()
            local ok = actions.tryTravel(state, "houston")
            assert.is_true(ok)
            assert.equal("houston", state.currentCity)
            assert.equal("modern",  state.currentPeriod)
        end)

        it("fails for a non-adjacent city", function()
            local ok, err = actions.tryTravel(state, "seattle")
            assert.is_false(ok)
            assert.not_nil(err)
        end)

        it("fails when already at destination", function()
            local ok = actions.tryTravel(state, "atlanta", "modern")
            assert.is_false(ok)
        end)

        it("crosses period via outpost (same city)", function()
            state.outposts["atlanta"] = true
            local ok = actions.tryTravel(state, "atlanta", "prehistory")
            assert.is_true(ok)
            assert.equal("atlanta",    state.currentCity)
            assert.equal("prehistory", state.currentPeriod)
        end)

        it("fails cross-period without outpost", function()
            local ok, err = actions.tryTravel(state, "atlanta", "prehistory")
            assert.is_false(ok)
            assert.not_nil(err)
        end)

        it("fails when changing both city and period", function()
            local ok = actions.tryTravel(state, "houston", "prehistory")
            assert.is_false(ok)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("tryTeleport", function()
        it("discards matching card and moves there", function()
            state.hand = {H.cityCard("seattle", "modern", "black")}
            local ok = actions.tryTeleport(state, "seattle", "modern")
            assert.is_true(ok)
            assert.equal("seattle", state.currentCity)
            assert.equal("modern",  state.currentPeriod)
            assert.equal(0, #state.hand)
            assert.equal(1, #state.playerDiscard)
        end)

        it("fails when card not in hand", function()
            local ok = actions.tryTeleport(state, "seattle", "modern")
            assert.is_false(ok)
        end)

        it("requires exact (city, period) match", function()
            state.hand = {H.cityCard("seattle", "prehistory", "blue")}
            local ok = actions.tryTeleport(state, "seattle", "modern")
            assert.is_false(ok)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("tryTeleportAlt", function()
        it("discards current location card and moves anywhere", function()
            state.hand = {H.cityCard("atlanta", "modern", "black")}
            local ok = actions.tryTeleportAlt(state, "seattle", "prehistory")
            assert.is_true(ok)
            assert.equal("seattle",    state.currentCity)
            assert.equal("prehistory", state.currentPeriod)
            assert.equal(0, #state.hand)
        end)

        it("fails when no card for current location in hand", function()
            state.hand = {H.cityCard("houston", "modern", "black")}
            local ok = actions.tryTeleportAlt(state, "seattle", "prehistory")
            assert.is_false(ok)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("tryBuildOutpost", function()
        it("places outpost and discards card", function()
            state.hand = {H.cityCard("atlanta", "prehistory", "blue")}
            local ok = actions.tryBuildOutpost(state)
            assert.is_true(ok)
            assert.is_true(state.outposts["atlanta"])
            assert.equal(1, #state.playerDiscard)
        end)

        it("accepts any period card for the current city", function()
            state.hand = {H.cityCard("atlanta", "far_future", "red")}
            local ok = actions.tryBuildOutpost(state)
            assert.is_true(ok)
        end)

        it("fails when no card for current city in hand", function()
            state.hand = {H.cityCard("chicago", "modern", "black")}
            local ok = actions.tryBuildOutpost(state)
            assert.is_false(ok)
        end)

        it("fails when outpost already exists", function()
            state.outposts["atlanta"] = true
            state.hand = {H.cityCard("atlanta", "modern", "black")}
            local ok = actions.tryBuildOutpost(state)
            assert.is_false(ok)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("tryClear", function()
        it("removes 1 cube of given color", function()
            state.cubes["atlanta"]["modern"]["black"] = 2
            local ok = actions.tryClear(state, "black")
            assert.is_true(ok)
            assert.equal(1, state.cubes["atlanta"]["modern"]["black"])
        end)

        it("removes all cubes of that color when anomaly is RESOLVED", function()
            state.cubes["atlanta"]["modern"]["black"] = 3
            state.resolved["black"] = true
            local ok = actions.tryClear(state, "black")
            assert.is_true(ok)
            assert.equal(0, state.cubes["atlanta"]["modern"]["black"])
        end)

        it("fails when no cube of that color at location", function()
            local ok = actions.tryClear(state, "black")
            assert.is_false(ok)
        end)

        it("marks anomaly REPAIRED when RESOLVED and board reaches 0", function()
            state.cubes["atlanta"]["modern"]["black"] = 1
            state.resolved["black"] = true
            actions.tryClear(state, "black")
            assert.is_true(state.repaired["black"])
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("tryResolve", function()
        local function hand5black()
            local h = {}
            for i = 1, 5 do h[i] = H.cityCard("atlanta", "modern", "black") end
            return h
        end

        it("resolves anomaly when at outpost with 5 matching cards", function()
            state.outposts["atlanta"] = true
            state.hand = hand5black()
            local ok = actions.tryResolve(state, "black")
            assert.is_true(ok)
            assert.is_true(state.resolved["black"])
            assert.equal(0, #state.hand)
            assert.equal(5, #state.playerDiscard)
        end)

        it("fails when not at an outpost", function()
            state.hand = hand5black()
            local ok = actions.tryResolve(state, "black")
            assert.is_false(ok)
        end)

        it("fails with fewer than 5 matching cards", function()
            state.outposts["atlanta"] = true
            state.hand = {H.cityCard("atlanta", "modern", "black"),
                          H.cityCard("atlanta", "modern", "black")}
            local ok = actions.tryResolve(state, "black")
            assert.is_false(ok)
            assert.equal(2, #state.hand)  -- cards returned
        end)

        it("fails when anomaly already RESOLVED", function()
            state.outposts["atlanta"] = true
            state.resolved["black"] = true
            state.hand = hand5black()
            local ok = actions.tryResolve(state, "black")
            assert.is_false(ok)
        end)

        it("marks REPAIRED when RESOLVED and no cubes remain", function()
            state.outposts["atlanta"] = true
            state.hand = hand5black()
            actions.tryResolve(state, "black")
            assert.is_true(state.repaired["black"])
        end)

        it("does not mark REPAIRED when cubes still remain", function()
            state.outposts["atlanta"] = true
            state.cubes["atlanta"]["modern"]["black"] = 1
            state.hand = hand5black()
            actions.tryResolve(state, "black")
            assert.is_false(state.repaired["black"])
        end)
    end)
end)
