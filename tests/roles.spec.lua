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

        it("auto-clears REPAIRED cubes at destination on teleport", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            -- Red is repaired and has cubes at atlanta/modern
            state.cubes["atlanta"]["modern"]["red"] = 2
            state.resolved["red"] = true
            state.repaired["red"] = true
            -- Give a card to teleport to atlanta/modern
            state.hand = { H.cityCard("atlanta", "modern", "black") }
            Roles.applyRole(state, "chronologist")
            local ok, err = Actions.tryTeleport(state, "atlanta", "modern")
            assert.is_true(ok, err)
            assert.equal(0, state.cubes["atlanta"]["modern"]["red"])
        end)

        it("does not clear cubes of non-repaired colors on arrival", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            state.cubes["atlanta"]["modern"]["blue"] = 2
            -- Blue is not repaired
            state.hand = { H.cityCard("atlanta", "modern", "black") }
            Roles.applyRole(state, "chronologist")
            Actions.tryTeleport(state, "atlanta", "modern")
            assert.equal(2, state.cubes["atlanta"]["modern"]["blue"])
        end)

        it("auto-clears REPAIRED cubes on travel", function()
            local state = H.makeState({
                currentCity   = "chicago",
                currentPeriod = "modern",
            })
            state.cubes["new_york"]["modern"]["black"] = 1
            state.resolved["black"] = true
            state.repaired["black"] = true
            Roles.applyRole(state, "chronologist")
            local ok = Actions.tryTravel(state, "new_york", "modern")
            assert.is_true(ok)
            assert.equal(0, state.cubes["new_york"]["modern"]["black"])
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
