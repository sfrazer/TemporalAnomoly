local winLose = require("src.rules.winLose")
local H       = require("tests.helpers")

describe("src.rules.winLose", function()
    local state

    before_each(function()
        state = H.makeState()
    end)

    it("returns nil when game is in progress", function()
        assert.is_nil(winLose.checkWinLose(state))
    end)

    -- -----------------------------------------------------------------------
    describe("loss conditions", function()
        it("returns lost when state.lost is set", function()
            state.lost = "player deck exhausted"
            local result, reason = winLose.checkWinLose(state)
            assert.equal("lost", result)
            assert.equal("player deck exhausted", reason)
        end)

        it("returns lost at 8 explosions", function()
            state.explosionCount = 8
            local result = winLose.checkWinLose(state)
            assert.equal("lost", result)
        end)

        it("still in progress at 7 explosions", function()
            state.explosionCount = 7
            assert.is_nil(winLose.checkWinLose(state))
        end)

        it("state.lost takes priority over explosion count", function()
            state.lost           = "supply exhausted"
            state.explosionCount = 3
            local result = winLose.checkWinLose(state)
            assert.equal("lost", result)
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("introductory win", function()
        before_each(function() state.difficulty = "introductory" end)

        it("wins at 2 resolved", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            assert.equal("won", winLose.checkWinLose(state))
        end)

        it("still in progress at 1 resolved", function()
            state.resolved.blue = true
            assert.is_nil(winLose.checkWinLose(state))
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("standard win", function()
        before_each(function() state.difficulty = "standard" end)

        it("wins at 3 resolved", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.resolved.black  = true
            assert.equal("won", winLose.checkWinLose(state))
        end)

        it("still in progress at 2 resolved", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            assert.is_nil(winLose.checkWinLose(state))
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("heroic win", function()
        before_each(function() state.difficulty = "heroic" end)

        it("wins with all 4 resolved", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.resolved.black  = true
            state.resolved.red    = true
            assert.equal("won", winLose.checkWinLose(state))
        end)

        it("wins via alternate path: 2 repaired", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.repaired.blue   = true
            state.repaired.yellow = true
            assert.equal("won", winLose.checkWinLose(state))
        end)

        it("still in progress at 3 resolved, 1 repaired", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.resolved.black  = true
            state.repaired.blue   = true
            assert.is_nil(winLose.checkWinLose(state))
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("legendary win", function()
        before_each(function()
            state.difficulty   = "legendary"
            state.priorityCity = "chicago"
        end)

        it("wins with all 4 resolved (priority city intact)", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.resolved.black  = true
            state.resolved.red    = true
            assert.equal("won", winLose.checkWinLose(state))
        end)

        it("loses when priority city explodes (via state.lost)", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.resolved.black  = true
            state.resolved.red    = true
            state.lost = "priority city exploded"
            assert.equal("lost", winLose.checkWinLose(state))
        end)

        it("still in progress at 3 resolved", function()
            state.resolved.blue   = true
            state.resolved.yellow = true
            state.resolved.black  = true
            assert.is_nil(winLose.checkWinLose(state))
        end)
    end)
end)
