local phases = require("src.rules.phases")
local H      = require("tests.helpers")

describe("src.rules.phases", function()
    local state

    before_each(function()
        state = H.makeState()
    end)

    -- -----------------------------------------------------------------------
    describe("runDrawPhase", function()
        it("draws 2 cards into hand", function()
            state.playerDeck = {
                H.cityCard("chicago", "modern", "black"),
                H.cityCard("seattle", "modern", "black"),
            }
            phases.runDrawPhase(state)
            assert.equal(2, #state.hand)
            assert.equal(0, #state.playerDeck)
        end)

        it("sets state.lost when deck is empty on first draw", function()
            state.playerDeck = {}
            phases.runDrawPhase(state)
            assert.not_nil(state.lost)
            assert.truthy(state.lost:find("exhausted"))
        end)

        it("sets state.lost when deck runs out mid-phase", function()
            state.playerDeck = {H.cityCard("chicago", "modern", "black")}
            phases.runDrawPhase(state)
            assert.not_nil(state.lost)
        end)

        it("resolves flux card immediately without adding to hand", function()
            -- Flux card + city card; flux should resolve, city should go to hand
            state.playerDeck = {
                H.fluxCard(),
                H.cityCard("chicago", "modern", "black"),
            }
            state.threatDeck    = {H.threatCard("atlanta", "modern", "black")}
            state.threatDiscard = {}
            local beforeIndex = state.instabilityIndex
            phases.runDrawPhase(state)
            assert.equal(1, #state.hand)  -- only the city card
            assert.is_true(state.instabilityIndex > beforeIndex)  -- flux advanced index
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("runInstabilityPhase", function()
        it("draws N cards equal to instability level", function()
            state.instabilityIndex = 1  -- level = 2
            state.threatDeck = {
                H.threatCard("atlanta", "modern",   "black"),
                H.threatCard("chicago", "modern",   "black"),
                H.threatCard("houston", "modern",   "black"),
            }
            phases.runInstabilityPhase(state)
            assert.equal(2, #state.threatDiscard)
            assert.equal(1, #state.threatDeck)
        end)

        it("places 1 cube per drawn card", function()
            state.instabilityIndex = 1  -- level = 2
            state.threatDeck = {
                H.threatCard("atlanta", "modern", "black"),
                H.threatCard("chicago", "modern", "black"),
            }
            phases.runInstabilityPhase(state)
            assert.equal(1, state.cubes["atlanta"]["modern"]["black"])
            assert.equal(1, state.cubes["chicago"]["modern"]["black"])
        end)

        it("skips cube placement for repaired colors", function()
            state.instabilityIndex  = 1  -- level = 2
            state.repaired["black"] = true
            state.threatDeck = {
                H.threatCard("atlanta", "modern", "black"),
                H.threatCard("chicago", "modern", "black"),
            }
            phases.runInstabilityPhase(state)
            assert.equal(0, state.cubes["atlanta"]["modern"]["black"])
            assert.equal(0, state.cubes["chicago"]["modern"]["black"])
        end)

        it("stops early if state.lost is set mid-phase", function()
            -- Exhaust black supply so the first placement triggers loss
            for _, c in ipairs(require("data.cities")) do
                for _, p in ipairs(require("data.periods")) do
                    state.cubes[c.id][p.id]["black"] = 0
                end
            end
            -- Set up 24 black cubes already on board so supply = 0
            state.cubes["atlanta"]["modern"]["black"]     = 3
            state.cubes["houston"]["modern"]["black"]     = 3
            state.cubes["chicago"]["modern"]["black"]     = 3
            state.cubes["new_york"]["modern"]["black"]    = 3
            state.cubes["seattle"]["modern"]["black"]     = 3
            state.cubes["los_angeles"]["modern"]["black"] = 3
            state.cubes["atlanta"]["prehistory"]["black"] = 2
            state.cubes["houston"]["prehistory"]["black"] = 2
            state.cubes["chicago"]["prehistory"]["black"] = 2
            -- 18+6=24 black cubes -> supply = 0
            state.instabilityIndex = 1  -- level = 2
            state.threatDeck = {
                H.threatCard("new_york",  "prehistory", "black"),
                H.threatCard("seattle",   "prehistory", "black"),
            }
            phases.runInstabilityPhase(state)
            assert.not_nil(state.lost)
        end)
    end)
end)
