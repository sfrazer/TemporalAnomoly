local Actions = require("src.rules.actions")
local Mod     = require("src.state.modifiers")
local H       = require("tests.helpers")

local function setup()
    Mod.clear()
    local gs = H.makeState()
    -- Give the player one of each playable event card
    gs.hand = {
        H.eventCard("paradox_barrier"),
        H.eventCard("unknown_assistance"),
        H.eventCard("temporal_slip"),
        H.eventCard("chrono_lock"),
        H.eventCard("chronological_rewind"),
        H.eventCard("time_corridor"),
        H.eventCard("temporal_seal"),
    }
    return gs
end

describe("Event cards", function()

    -- -------------------------------------------------------------------------
    describe("paradox_barrier", function()

        it("sets skipNextInstability and discards the card", function()
            local gs = setup()
            local ok = Actions.tryPlayCard(gs, 1)
            assert.is_true(ok)
            assert.is_true(gs.skipNextInstability)
            assert.equals(6, #gs.hand)
            assert.equals(1, #gs.playerDiscard)
            assert.equals("paradox_barrier", gs.playerDiscard[1].id)
        end)

        it("always succeeds", function()
            local gs = setup()
            local ok = Actions.tryPlayCard(gs, 1)
            assert.is_true(ok)
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("unknown_assistance", function()

        it("builds outpost in chosen city and discards card", function()
            local gs = setup()
            local ok = Actions.tryPlayCard(gs, 2, "seattle")
            assert.is_true(ok)
            assert.is_true(gs.outposts["seattle"])
            assert.equals(6, #gs.hand)
            assert.equals("unknown_assistance", gs.playerDiscard[1].id)
        end)

        it("fails if outpost already exists", function()
            local gs = setup()
            gs.outposts["seattle"] = true
            local ok, err = Actions.tryPlayCard(gs, 2, "seattle")
            assert.is_false(ok)
            assert.truthy(err)
            assert.equals(7, #gs.hand)
            assert.equals(0, #gs.playerDiscard)
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("temporal_slip", function()

        it("moves player to chosen city/period and discards card", function()
            local gs = setup()
            local ok = Actions.tryPlayCard(gs, 3, "seattle", "prehistory")
            assert.is_true(ok)
            assert.equals("seattle",    gs.currentCity)
            assert.equals("prehistory", gs.currentPeriod)
            assert.equals(6, #gs.hand)
            assert.equals("temporal_slip", gs.playerDiscard[1].id)
        end)

        it("fires onArrive", function()
            local gs = setup()
            local arrived = false
            Mod.register("onArrive", function() arrived = true end)
            Actions.tryPlayCard(gs, 3, "seattle", "prehistory")
            assert.is_true(arrived)
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("chrono_lock", function()

        it("removes chosen threat discard card permanently", function()
            local gs = setup()
            gs.threatDiscard = {
                H.threatCard("chicago", "modern", "black"),
                H.threatCard("houston", "far_future", "red"),
            }
            local ok = Actions.tryPlayCard(gs, 4, 1)
            assert.is_true(ok)
            assert.equals(1, #gs.threatDiscard)
            assert.equals("houston", gs.threatDiscard[1].city)
            assert.equals(6, #gs.hand)
            assert.equals("chrono_lock", gs.playerDiscard[1].id)
        end)

        it("fails and does not consume card when threat discard is empty", function()
            local gs = setup()
            gs.threatDiscard = {}
            local ok, err = Actions.tryPlayCard(gs, 4)
            assert.is_false(ok)
            assert.truthy(err)
            assert.equals(7, #gs.hand)
            assert.equals(0, #gs.playerDiscard)
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("chronological_rewind", function()

        it("clears all cubes of chosen color in current city across all periods", function()
            local gs = setup()
            gs.currentCity = "atlanta"
            gs.cubes["atlanta"]["prehistory"]["blue"]  = 2
            gs.cubes["atlanta"]["industrial"]["blue"]  = 1
            gs.cubes["atlanta"]["modern"]["blue"]      = 3
            gs.cubes["atlanta"]["far_future"]["blue"]  = 2
            gs.cubes["atlanta"]["modern"]["red"]       = 1  -- different color, untouched
            local ok = Actions.tryPlayCard(gs, 5, "blue")
            assert.is_true(ok)
            assert.equals(0, gs.cubes["atlanta"]["prehistory"]["blue"])
            assert.equals(0, gs.cubes["atlanta"]["industrial"]["blue"])
            assert.equals(0, gs.cubes["atlanta"]["modern"]["blue"])
            assert.equals(0, gs.cubes["atlanta"]["far_future"]["blue"])
            assert.equals(1, gs.cubes["atlanta"]["modern"]["red"])
            assert.equals(6, #gs.hand)
            assert.equals("chronological_rewind", gs.playerDiscard[1].id)
        end)

        it("only clears cubes in current city, not other cities", function()
            local gs = setup()
            gs.currentCity = "atlanta"
            gs.cubes["atlanta"]["modern"]["blue"] = 2
            gs.cubes["chicago"]["modern"]["blue"] = 2
            Actions.tryPlayCard(gs, 5, "blue")
            assert.equals(0, gs.cubes["atlanta"]["modern"]["blue"])
            assert.equals(2, gs.cubes["chicago"]["modern"]["blue"])
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("time_corridor", function()

        it("adds 2 to actionsRemaining and discards card", function()
            local gs = setup()
            gs.actionsRemaining = 2
            local ok = Actions.tryPlayCard(gs, 6)
            assert.is_true(ok)
            assert.equals(4, gs.actionsRemaining)
            assert.equals(6, #gs.hand)
            assert.equals("time_corridor", gs.playerDiscard[1].id)
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("temporal_seal", function()

        it("sets sealedCity and discards card", function()
            local gs = setup()
            local ok = Actions.tryPlayCard(gs, 7, "houston")
            assert.is_true(ok)
            assert.equals("houston", gs.sealedCity)
            assert.equals(6, #gs.hand)
            assert.equals("temporal_seal", gs.playerDiscard[1].id)
        end)

        it("allows resealing an already-sealed city", function()
            local gs = setup()
            gs.sealedCity = "houston"
            local ok = Actions.tryPlayCard(gs, 7, "houston")
            assert.is_true(ok)
            assert.equals("houston", gs.sealedCity)
        end)

        it("allows sealing a different city when one is already sealed", function()
            local gs = setup()
            gs.sealedCity = "houston"
            local ok = Actions.tryPlayCard(gs, 7, "seattle")
            assert.is_true(ok)
            assert.equals("seattle", gs.sealedCity)
        end)

    end)

    -- -------------------------------------------------------------------------
    describe("stubs (mobile_outpost, supply_drop)", function()

        it("mobile_outpost returns false and does not consume card", function()
            local gs = H.makeState()
            gs.hand = {H.eventCard("mobile_outpost")}
            local ok, err = Actions.tryPlayCard(gs, 1)
            assert.is_false(ok)
            assert.truthy(err)
            assert.equals(1, #gs.hand)
            assert.equals(0, #gs.playerDiscard)
        end)

        it("supply_drop returns false and does not consume card", function()
            local gs = H.makeState()
            gs.hand = {H.eventCard("supply_drop")}
            local ok, err = Actions.tryPlayCard(gs, 1)
            assert.is_false(ok)
            assert.truthy(err)
            assert.equals(1, #gs.hand)
            assert.equals(0, #gs.playerDiscard)
        end)

    end)

end)
