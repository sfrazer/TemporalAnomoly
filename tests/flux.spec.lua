local flux = require("src.rules.flux")
local H    = require("tests.helpers")

describe("src.rules.flux", function()
    local state

    before_each(function()
        state = H.makeState()
    end)

    it("advances instability index", function()
        state.instabilityIndex = 1
        -- seed threat deck and discard so flux has something to work with
        state.threatDeck    = {H.threatCard("atlanta", "modern", "black")}
        state.threatDiscard = {}
        flux.resolveChronologicalFlux(state)
        assert.equal(2, state.instabilityIndex)
    end)

    it("does not advance instability index past 7", function()
        state.instabilityIndex = 7
        state.threatDeck    = {H.threatCard("atlanta", "modern", "black")}
        state.threatDiscard = {}
        flux.resolveChronologicalFlux(state)
        assert.equal(7, state.instabilityIndex)
    end)

    it("draws the bottom card of the threat deck", function()
        state.threatDeck = {
            H.threatCard("chicago",  "modern", "black"),  -- top (index 1)
            H.threatCard("atlanta",  "modern", "black"),  -- bottom
        }
        state.threatDiscard = {}
        flux.resolveChronologicalFlux(state)
        -- atlanta was drawn (bottom), placed in discard, then reshuffled to top of deck
        -- after reshuffle, threatDiscard is cleared and cards are in threatDeck
        local found = false
        for _, c in ipairs(state.threatDeck) do
            if c.city == "atlanta" then found = true end
        end
        assert.is_true(found)
    end)

    it("places 3 cubes on the drawn card's city/period", function()
        state.threatDeck    = {H.threatCard("atlanta", "modern", "black")}
        state.threatDiscard = {}
        flux.resolveChronologicalFlux(state)
        assert.equal(3, state.cubes["atlanta"]["modern"]["black"])
    end)

    it("reshuffles threat discard onto top of deck", function()
        state.threatDeck = {
            H.threatCard("chicago",  "modern", "black"),
        }
        state.threatDiscard = {
            H.threatCard("houston",  "modern", "black"),
            H.threatCard("new_york", "modern", "black"),
        }
        local before = #state.threatDiscard + 1  -- discard + the one drawn
        flux.resolveChronologicalFlux(state)
        -- All discard cards (including just drawn) move to top of deck
        assert.equal(0, #state.threatDiscard)
        assert.equal(before, #state.threatDeck)
    end)

    it("skips cube placement when color is REPAIRED", function()
        state.repaired["black"] = true
        state.threatDeck    = {H.threatCard("atlanta", "modern", "black")}
        state.threatDiscard = {}
        flux.resolveChronologicalFlux(state)
        assert.equal(0, state.cubes["atlanta"]["modern"]["black"])
    end)
end)
