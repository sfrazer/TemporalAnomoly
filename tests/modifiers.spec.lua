local Mod     = require("src.state.modifiers")
local actions = require("src.rules.actions")
local expl    = require("src.rules.explosion")
local phases  = require("src.rules.phases")
local H       = require("tests.helpers")

-- Reset the pipeline before every test so registered handlers don't bleed over.
before_each(function() Mod.clear() end)

describe("src.state.modifiers", function()

    -- -----------------------------------------------------------------------
    describe("fold (numeric hooks)", function()
        it("returns the base value when no handlers registered", function()
            assert.equal(4, Mod.actionsPerTurn({}))
            assert.equal(2, Mod.cardsDrawnPerTurn({}))
            assert.equal(1, Mod.cubesPerThreatCard({}))
            assert.equal(5, Mod.cardsToResolveAnomaly({}))
            assert.equal(1, Mod.cubesRemovedPerClear({}, {}))
        end)

        it("applies a single handler", function()
            Mod.register("actionsPerTurn", function(state, v) return v + 1 end)
            assert.equal(5, Mod.actionsPerTurn({}))
        end)

        it("applies handlers in registration order", function()
            -- first doubles, second adds 1: (4*2)+1 = 9
            Mod.register("actionsPerTurn", function(s, v) return v * 2 end)
            Mod.register("actionsPerTurn", function(s, v) return v + 1 end)
            assert.equal(9, Mod.actionsPerTurn({}))
        end)

        it("passes ctx to cubesRemovedPerClear handler", function()
            local got_ctx
            Mod.register("cubesRemovedPerClear", function(s, v, ctx)
                got_ctx = ctx
                return v
            end)
            local ctx = {city = "atlanta", period = "modern", color = "black"}
            Mod.cubesRemovedPerClear({}, ctx)
            assert.equal(ctx, got_ctx)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("permit (permission hooks)", function()
        it("returns true when no handlers registered", function()
            assert.is_true(Mod.canTravel({}, {}, {}))
            assert.is_true(Mod.canBuildOutpost({}, "atlanta"))
            assert.is_true(Mod.canPlaceCube({}, "atlanta", "modern", "black"))
        end)

        it("returns true when all handlers return true", function()
            Mod.register("canTravel", function() return true end)
            Mod.register("canTravel", function() return true end)
            assert.is_true(Mod.canTravel({}, {}, {}))
        end)

        it("returns false when any handler returns false (veto-AND)", function()
            Mod.register("canTravel", function() return true  end)
            Mod.register("canTravel", function() return false end)
            Mod.register("canTravel", function() return true  end)
            assert.is_false(Mod.canTravel({}, {}, {}))
        end)

        it("passes city/period/color args to canPlaceCube handler", function()
            local got = {}
            Mod.register("canPlaceCube", function(s, city, period, color)
                got = {city = city, period = period, color = color}
                return true
            end)
            Mod.canPlaceCube({}, "atlanta", "modern", "black")
            assert.equal("atlanta", got.city)
            assert.equal("modern",  got.period)
            assert.equal("black",   got.color)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("fire (event hooks)", function()
        it("calls all registered handlers", function()
            local called = 0
            Mod.register("onTemporalExplosion", function() called = called + 1 end)
            Mod.register("onTemporalExplosion", function() called = called + 1 end)
            Mod.onTemporalExplosion({}, {})
            assert.equal(2, called)
        end)

        it("passes ctx to handler", function()
            local got_ctx
            Mod.register("onThreatCardDraw", function(s, ctx) got_ctx = ctx end)
            local ctx = {card = {city = "atlanta"}}
            Mod.onThreatCardDraw({}, ctx)
            assert.equal(ctx, got_ctx)
        end)

        it("does nothing when no handlers registered", function()
            assert.has_no.errors(function()
                Mod.onChronologicalFlux({}, {})
            end)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("clear", function()
        it("removes all registered handlers", function()
            Mod.register("actionsPerTurn", function(s, v) return v + 10 end)
            Mod.clear()
            assert.equal(4, Mod.actionsPerTurn({}))
        end)
    end)

end)

-- ---------------------------------------------------------------------------
-- Integration: verify rules respect the pipeline
-- ---------------------------------------------------------------------------
describe("modifiers integration", function()
    local state

    before_each(function()
        Mod.clear()
        state = H.makeState()
    end)

    it("tryResolve uses cardsToResolveAnomaly (Physicist: 4 cards)", function()
        Mod.register("cardsToResolveAnomaly", function(s, v) return v - 1 end)
        state.outposts["atlanta"] = true
        for i = 1, 4 do
            state.hand[i] = H.cityCard("atlanta", "modern", "black")
        end
        local ok = actions.tryResolve(state, "black")
        assert.is_true(ok)
    end)

    it("tryResolve still fails with 3 cards when modifier gives 4", function()
        Mod.register("cardsToResolveAnomaly", function(s, v) return v - 1 end)
        state.outposts["atlanta"] = true
        for i = 1, 3 do
            state.hand[i] = H.cityCard("atlanta", "modern", "black")
        end
        local ok = actions.tryResolve(state, "black")
        assert.is_false(ok)
    end)

    it("tryClear uses cubesRemovedPerClear (Chronologist: remove all)", function()
        -- Handler: remove all cubes instead of 1
        Mod.register("cubesRemovedPerClear", function(s, v, ctx)
            return s.cubes[ctx.city][ctx.period][ctx.color]
        end)
        state.cubes["atlanta"]["modern"]["black"] = 3
        actions.tryClear(state, "black")
        assert.equal(0, state.cubes["atlanta"]["modern"]["black"])
    end)

    it("tryTravel respects canTravel veto", function()
        Mod.register("canTravel", function() return false end)
        local ok = actions.tryTravel(state, "houston")
        assert.is_false(ok)
    end)

    it("canPlaceCube veto prevents cube placement", function()
        -- Block all cube placement in atlanta
        Mod.register("canPlaceCube", function(s, city) return city ~= "atlanta" end)
        expl.placeCubesAt(state, "atlanta", "modern", "black", 1)
        assert.equal(0, state.cubes["atlanta"]["modern"]["black"])
    end)

    it("runDrawPhase uses cardsDrawnPerTurn", function()
        Mod.register("cardsDrawnPerTurn", function(s, v) return v + 1 end)  -- draw 3
        state.playerDeck = {
            H.cityCard("atlanta", "modern", "black"),
            H.cityCard("chicago", "modern", "black"),
            H.cityCard("houston", "modern", "black"),
        }
        phases.runDrawPhase(state)
        assert.equal(3, #state.hand)
    end)

    it("runInstabilityPhase uses cubesPerThreatCard", function()
        Mod.register("cubesPerThreatCard", function(s, v) return v + 1 end)  -- 2 cubes
        state.instabilityIndex = 1  -- level = 2, but only 1 card in deck
        state.threatDeck = {H.threatCard("atlanta", "modern", "black")}
        phases.runInstabilityPhase(state)
        assert.equal(2, state.cubes["atlanta"]["modern"]["black"])
    end)

    it("onTemporalExplosion fires when explosion occurs", function()
        local fired = false
        Mod.register("onTemporalExplosion", function() fired = true end)
        state.cubes["atlanta"]["modern"]["black"] = 3
        expl.placeCubesAt(state, "atlanta", "modern", "black", 1)
        assert.is_true(fired)
    end)

    it("onThreatCardDraw fires during instability phase", function()
        local drawn = {}
        Mod.register("onThreatCardDraw", function(s, ctx) drawn[#drawn+1] = ctx.card end)
        state.instabilityIndex = 1
        state.threatDeck = {
            H.threatCard("atlanta", "modern", "black"),
            H.threatCard("chicago", "modern", "black"),
        }
        phases.runInstabilityPhase(state)
        assert.equal(2, #drawn)
    end)

    it("onChronologicalFlux fires during flux resolution", function()
        local fired = false
        Mod.register("onChronologicalFlux", function() fired = true end)
        local flux = require("src.rules.flux")
        state.threatDeck    = {H.threatCard("atlanta", "modern", "black")}
        state.threatDiscard = {}
        flux.resolveChronologicalFlux(state)
        assert.is_true(fired)
    end)
end)
