local Mod     = require("src.state.modifiers")
local Roles   = require("src.rules.roles")
local Actions = require("src.rules.actions")
local H       = require("tests.helpers")

describe("Roles", function()
    before_each(function()
        Mod.clear()
    end)

    -- -------------------------------------------------------------------------
    describe("Physicist", function()
        it("reduces cardsToResolveAnomaly to 4", function()
            local state = H.makeState()
            Roles.applyRole(state, "physicist")
            assert.equal(4, Mod.cardsToResolveAnomaly(state))
        end)

        it("succeeds resolving with 4 cards at an outpost", function()
            local state = H.makeState()
            state.outposts["atlanta"] = true
            state.hand = {
                H.cityCard("seattle", "prehistory", "blue"),
                H.cityCard("chicago", "prehistory", "blue"),
                H.cityCard("houston", "prehistory", "blue"),
                H.cityCard("new_york", "prehistory", "blue"),
            }
            Roles.applyRole(state, "physicist")
            local ok, err = Actions.tryResolve(state, "blue")
            assert.is_true(ok, err)
            assert.is_true(state.resolved["blue"])
        end)

        it("fails to resolve with only 3 cards even as Physicist", function()
            local state = H.makeState()
            state.outposts["atlanta"] = true
            state.hand = {
                H.cityCard("seattle", "prehistory", "blue"),
                H.cityCard("chicago", "prehistory", "blue"),
                H.cityCard("houston", "prehistory", "blue"),
            }
            Roles.applyRole(state, "physicist")
            local ok = Actions.tryResolve(state, "blue")
            assert.is_false(ok)
        end)

        it("stacks correctly: two Physicist handlers reduce by 2", function()
            local state = H.makeState()
            Roles.applyRole(state, "physicist")
            Roles.applyRole(state, "physicist")
            assert.equal(3, Mod.cardsToResolveAnomaly(state))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Chronologist", function()
        it("cubesRemovedPerClear returns a value large enough to clear 3 cubes", function()
            local state = H.makeState()
            Roles.applyRole(state, "chronologist")
            local ctx = {city = "atlanta", period = "modern", color = "blue"}
            assert.is_true(Mod.cubesRemovedPerClear(state, ctx) >= 3)
        end)

        it("clears all cubes of chosen color when there are 3", function()
            local state = H.makeState()
            state.cubes["atlanta"]["modern"]["blue"] = 3
            Roles.applyRole(state, "chronologist")
            local ok, err = Actions.tryClear(state, "blue")
            assert.is_true(ok, err)
            assert.equal(0, state.cubes["atlanta"]["modern"]["blue"])
        end)

        it("clears all cubes even when anomaly is not resolved", function()
            local state = H.makeState()
            state.cubes["atlanta"]["modern"]["yellow"] = 2
            assert.is_false(state.resolved["yellow"])
            Roles.applyRole(state, "chronologist")
            local ok = Actions.tryClear(state, "yellow")
            assert.is_true(ok)
            assert.equal(0, state.cubes["atlanta"]["modern"]["yellow"])
        end)

        it("auto-clears RESOLVED cubes at destination on teleport", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            state.cubes["atlanta"]["modern"]["red"] = 2
            state.resolved["red"] = true
            state.hand = { H.cityCard("atlanta", "modern", "black") }
            Roles.applyRole(state, "chronologist")
            local ok, err = Actions.tryTeleport(state, "atlanta", "modern")
            assert.is_true(ok, err)
            assert.equal(0, state.cubes["atlanta"]["modern"]["red"])
        end)

        it("does not clear cubes of non-resolved colors on arrival", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            state.cubes["atlanta"]["modern"]["blue"] = 2
            -- Blue is not resolved
            state.hand = { H.cityCard("atlanta", "modern", "black") }
            Roles.applyRole(state, "chronologist")
            Actions.tryTeleport(state, "atlanta", "modern")
            assert.equal(2, state.cubes["atlanta"]["modern"]["blue"])
        end)

        it("auto-clears RESOLVED cubes on travel", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            state.cubes["new_york"]["modern"]["black"] = 1
            state.resolved["black"] = true
            Roles.applyRole(state, "chronologist")
            local ok = Actions.tryTravel(state, "new_york", "modern")
            assert.is_true(ok)
            assert.equal(0, state.cubes["new_york"]["modern"]["black"])
        end)

        it("advances anomaly to REPAIRED after clearing last cube on arrival", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            -- black is resolved with exactly 1 cube left on the whole board
            state.cubes["new_york"]["modern"]["black"] = 1
            state.resolved["black"] = true
            Roles.applyRole(state, "chronologist")
            Actions.tryTravel(state, "new_york", "modern")
            assert.equal(0, state.cubes["new_york"]["modern"]["black"])
            assert.is_true(state.repaired["black"])
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Coordinator", function()
        it("moves to an outpost city without spending an action", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            state.role = "coordinator"
            state.outposts["atlanta"] = true
            local ok, err = Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_true(ok, err)
            assert.equal("atlanta", state.currentCity)
            assert.equal("modern", state.currentPeriod)
        end)

        it("sets coordinatorMoveUsed after use", function()
            local state = H.makeState({currentCity = "chicago"})
            state.role = "coordinator"
            state.outposts["atlanta"] = true
            Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_true(state.coordinatorMoveUsed)
        end)

        it("fails when move already used this turn", function()
            local state = H.makeState({currentCity = "chicago"})
            state.role = "coordinator"
            state.coordinatorMoveUsed = true
            state.outposts["atlanta"] = true
            local ok = Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_false(ok)
        end)

        it("fails when destination has no Temporal Outpost", function()
            local state = H.makeState({currentCity = "chicago"})
            state.role = "coordinator"
            local ok = Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_false(ok)
        end)

        it("fails when called for a non-coordinator role", function()
            local state = H.makeState({currentCity = "chicago"})
            state.role = "physicist"
            state.outposts["atlanta"] = true
            local ok = Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_false(ok)
        end)

        it("fails when already at the destination", function()
            local state = H.makeState({currentCity = "atlanta"})
            state.role = "coordinator"
            state.outposts["atlanta"] = true
            local ok = Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_false(ok)
        end)

        it("fires onArrive when moving", function()
            local state = H.makeState({currentCity = "chicago"})
            state.role = "coordinator"
            state.outposts["atlanta"] = true
            local arrived = false
            Mod.register("onArrive", function(s, ctx)
                arrived = true
            end)
            Actions.tryCoordinatorMove(state, "atlanta")
            assert.is_true(arrived)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Temporal Isolationist", function()
        it("blocks cube placement in current city", function()
            local state = H.makeState({currentCity = "atlanta"})
            Roles.applyRole(state, "temporal_isolationist")
            assert.is_false(Mod.canPlaceCube(state, "atlanta", "modern", "blue"))
        end)

        it("blocks cube placement in adjacent cities", function()
            local state = H.makeState({currentCity = "atlanta"})
            Roles.applyRole(state, "temporal_isolationist")
            -- atlanta is adjacent to houston and new_york
            assert.is_false(Mod.canPlaceCube(state, "houston",  "modern", "blue"))
            assert.is_false(Mod.canPlaceCube(state, "new_york", "modern", "blue"))
        end)

        it("allows cube placement in non-adjacent cities", function()
            local state = H.makeState({currentCity = "atlanta"})
            Roles.applyRole(state, "temporal_isolationist")
            -- seattle is not adjacent to atlanta
            assert.is_true(Mod.canPlaceCube(state, "seattle",     "modern", "blue"))
            assert.is_true(Mod.canPlaceCube(state, "los_angeles", "modern", "blue"))
        end)

        it("protection follows player when they move", function()
            local state = H.makeState({currentCity = "atlanta"})
            Roles.applyRole(state, "temporal_isolationist")
            -- chicago is not adjacent to atlanta — currently allowed
            assert.is_true(Mod.canPlaceCube(state, "chicago", "modern", "blue"))
            -- move to chicago
            state.currentCity = "chicago"
            -- now chicago is blocked
            assert.is_false(Mod.canPlaceCube(state, "chicago", "modern", "blue"))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Engineer", function()
        it("tryBuildOutpost succeeds with empty hand", function()
            local state = H.makeState({currentCity = "atlanta"})
            state.hand = {}
            Roles.applyRole(state, "engineer")
            local ok = Actions.tryBuildOutpost(state)
            assert.is_true(ok)
            assert.is_true(state.outposts["atlanta"])
        end)

        it("consumes no card (playerDiscard stays empty)", function()
            local state = H.makeState({currentCity = "atlanta"})
            state.hand = {}
            Roles.applyRole(state, "engineer")
            Actions.tryBuildOutpost(state)
            assert.equals(0, #state.playerDiscard)
        end)

        it("still fails when outpost already exists", function()
            local state = H.makeState({currentCity = "atlanta"})
            state.outposts["atlanta"] = true
            Roles.applyRole(state, "engineer")
            local ok = Actions.tryBuildOutpost(state)
            assert.is_false(ok)
        end)

        it("outpostCardRequired returns false", function()
            local state = H.makeState()
            Roles.applyRole(state, "engineer")
            assert.is_false(Mod.outpostCardRequired(state))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Researcher", function()
        it("draws 1 extra card into hand on apply", function()
            local state = H.makeState()
            state.playerDeck = {
                H.cityCard("chicago", "modern", "black"),
                H.cityCard("seattle", "prehistory", "blue"),
                H.cityCard("houston", "far_future", "red"),
            }
            state.hand = {}
            Roles.applyRole(state, "researcher")
            assert.equals(1, #state.hand)
        end)

        it("inserts a chronological_rewind into the player deck", function()
            local state = H.makeState()
            state.playerDeck = {H.cityCard("chicago", "modern", "black")}
            state.hand = {}
            Roles.applyRole(state, "researcher")
            local found = false
            for _, c in ipairs(state.playerDeck) do
                if c.id == "chronological_rewind" then found = true end
            end
            assert.is_true(found)
        end)

        it("chronological_rewind card has type 'event'", function()
            local state = H.makeState()
            state.playerDeck = {H.cityCard("chicago", "modern", "black")}
            state.hand = {}
            Roles.applyRole(state, "researcher")
            for _, c in ipairs(state.playerDeck) do
                if c.id == "chronological_rewind" then
                    assert.equals("event", c.type)
                end
            end
        end)

        it("does not crash when deck is empty", function()
            local state = H.makeState()
            state.playerDeck = {}
            state.hand = {}
            assert.has_no.errors(function()
                Roles.applyRole(state, "researcher")
            end)
            assert.equals(1, #state.playerDeck)  -- only the inserted rewind
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Failsafe Designer", function()
        it("tryRetrieveCard moves event card from discard to hand", function()
            local state = H.makeState()
            Roles.applyRole(state, "failsafe_designer")
            state.playerDiscard = {H.eventCard("paradox_barrier")}
            local ok = Actions.tryRetrieveCard(state, 1)
            assert.is_true(ok)
            assert.equals(0, #state.playerDiscard)
            assert.equals(1, #state.hand)
            assert.equals("paradox_barrier", state.hand[1].id)
        end)

        it("sets failsafeDesignerUsed after use", function()
            local state = H.makeState()
            Roles.applyRole(state, "failsafe_designer")
            state.playerDiscard = {H.eventCard("temporal_slip")}
            Actions.tryRetrieveCard(state, 1)
            assert.is_true(state.failsafeDesignerUsed)
        end)

        it("fails on second call (once per run)", function()
            local state = H.makeState()
            Roles.applyRole(state, "failsafe_designer")
            state.playerDiscard = {H.eventCard("paradox_barrier"), H.eventCard("temporal_slip")}
            Actions.tryRetrieveCard(state, 1)
            local ok, err = Actions.tryRetrieveCard(state, 1)
            assert.is_false(ok)
            assert.truthy(err)
        end)

        it("fails if chosen discard entry is not an event card", function()
            local state = H.makeState()
            Roles.applyRole(state, "failsafe_designer")
            state.playerDiscard = {H.cityCard("chicago", "modern", "black")}
            local ok, err = Actions.tryRetrieveCard(state, 1)
            assert.is_false(ok)
            assert.truthy(err)
            assert.equals(0, #state.hand)
        end)

        it("fails with out-of-range index", function()
            local state = H.makeState()
            Roles.applyRole(state, "failsafe_designer")
            state.playerDiscard = {}
            local ok, err = Actions.tryRetrieveCard(state, 1)
            assert.is_false(ok)
            assert.truthy(err)
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Temporal Analyst", function()
        it("applyRole does not error", function()
            assert.has_no.errors(function()
                local state = H.makeState()
                Roles.applyRole(state, "temporal_analyst")
            end)
        end)

        it("registers no passive modifier hooks", function()
            local state = H.makeState({currentCity = "atlanta"})
            Roles.applyRole(state, "temporal_analyst")
            -- canPlaceCube unaffected (no veto)
            assert.is_true(Mod.canPlaceCube(state, "atlanta", "modern", "blue"))
            -- outpostCardRequired unaffected (still true)
            assert.is_true(Mod.outpostCardRequired(state))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("Chronomancer", function()
        it("tryReorderThreats reorders the top N cards of the threat deck", function()
            local state = H.makeState()
            local c1 = H.threatCard("atlanta",     "modern",     "black")
            local c2 = H.threatCard("houston",     "modern",     "black")
            local c3 = H.threatCard("chicago",     "industrial", "yellow")
            state.threatDeck = {c1, c2, c3}
            local ok = Actions.tryReorderThreats(state, {c3, c1, c2})
            assert.is_true(ok)
            assert.equal(c3, state.threatDeck[1])
            assert.equal(c1, state.threatDeck[2])
            assert.equal(c2, state.threatDeck[3])
        end)

        it("sets chronomancerUsed after use", function()
            local state = H.makeState()
            local c = H.threatCard("atlanta", "modern", "black")
            state.threatDeck = {c}
            Actions.tryReorderThreats(state, {c})
            assert.is_true(state.chronomancerUsed)
        end)

        it("fails on second use", function()
            local state = H.makeState()
            state.chronomancerUsed = true
            local ok, err = Actions.tryReorderThreats(state, {})
            assert.is_false(ok)
            assert.not_nil(err)
        end)

        it("works on a deck shorter than 6", function()
            local state = H.makeState()
            local c = H.threatCard("seattle", "prehistory", "blue")
            state.threatDeck = {c}
            local ok = Actions.tryReorderThreats(state, {c})
            assert.is_true(ok)
            assert.equal(c, state.threatDeck[1])
            assert.equal(1, #state.threatDeck)
        end)

        it("applyRole registers no passive modifier hooks", function()
            local state = H.makeState()
            Roles.applyRole(state, "chronomancer")
            assert.is_true(Mod.canPlaceCube(state, "atlanta", "modern", "blue"))
            assert.is_true(Mod.outpostCardRequired(state))
            assert.equal(5, Mod.cardsToResolveAnomaly(state))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("applyRole", function()
        it("does not error for an unknown role id", function()
            local state = H.makeState()
            assert.has_no.error(function()
                Roles.applyRole(state, "nonexistent_role")
            end)
        end)

        it("does not error for nil role id", function()
            local state = H.makeState()
            assert.has_no.error(function()
                Roles.applyRole(state, nil)
            end)
        end)
    end)
end)
