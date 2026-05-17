local gameState = require("src.state.gameState")
local cities    = require("data.cities")
local periods   = require("data.periods")

local FLUX = {introductory = 4, standard = 5, heroic = 6, legendary = 7}
local HAND = 4

describe("src.state.gameState", function()
    local state

    before_each(function()
        math.randomseed(42)
        state = gameState.new({difficulty = "standard"})
    end)

    it("returns a table", function()
        assert.is_table(state)
    end)

    it("hand has " .. HAND .. " cards", function()
        assert.equal(HAND, #state.hand)
    end)

    it("hand contains no flux cards (flux added after dealing)", function()
        for _, c in ipairs(state.hand) do
            assert.not_equal("flux", c.type)
        end
    end)

    it("player deck has 52 - hand + flux cards", function()
        local fluxN = FLUX["standard"]
        assert.equal(52 - HAND + fluxN, #state.playerDeck)
    end)

    it("flux card count in deck matches difficulty", function()
        for diff, expected in pairs(FLUX) do
            math.randomseed(42)
            local s = gameState.new({difficulty = diff})
            local n = 0
            for _, c in ipairs(s.playerDeck) do
                if c.type == "flux" then n = n + 1 end
            end
            assert.equal(expected, n, diff .. " should have " .. expected .. " flux cards")
        end
    end)

    it("threat deck has 18 cards (24 - 6 seeded)", function()
        assert.equal(18, #state.threatDeck)
    end)

    it("threat discard has 6 cards from seeding", function()
        assert.equal(6, #state.threatDiscard)
    end)

    it("total cubes seeded = 3+3+2+2+1+1 = 12", function()
        local total = 0
        for _, cityData in pairs(state.cubes) do
            for _, periodData in pairs(cityData) do
                for _, color in ipairs({"blue","yellow","black","red"}) do
                    total = total + (periodData[color] or 0)
                end
            end
        end
        assert.equal(12, total)
    end)

    it("cubes table covers all (city, period) pairs", function()
        for _, city in ipairs(cities) do
            assert.is_table(state.cubes[city.id])
            for _, period in ipairs(periods) do
                assert.is_table(state.cubes[city.id][period.id])
            end
        end
    end)

    it("all anomalies start unresolved and unrepaired", function()
        for _, color in ipairs({"blue","yellow","black","red"}) do
            assert.is_false(state.resolved[color])
            assert.is_false(state.repaired[color])
        end
    end)

    it("no outposts at start", function()
        assert.is_nil(next(state.outposts))
    end)

    it("instability index starts at 1", function()
        assert.equal(1, state.instabilityIndex)
    end)

    it("explosion count starts at 0", function()
        assert.equal(0, state.explosionCount)
    end)

    it("legendary difficulty sets a priority city", function()
        math.randomseed(42)
        local s = gameState.new({difficulty = "legendary"})
        assert.not_nil(s.priorityCity)
    end)

    it("non-legendary difficulty has no priority city", function()
        assert.is_nil(state.priorityCity)
    end)
end)
