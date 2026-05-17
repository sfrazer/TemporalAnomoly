local util = require("src.util")

describe("src.util", function()
    describe("shuffle", function()
        it("returns the same table reference", function()
            local t = {1, 2, 3}
            assert.equal(t, util.shuffle(t))
        end)
        it("preserves all elements", function()
            local orig = {1, 2, 3, 4, 5}
            local t    = {table.unpack(orig)}
            util.shuffle(t)
            table.sort(t); table.sort(orig)
            for i = 1, #orig do assert.equal(orig[i], t[i]) end
        end)
    end)

    describe("drawTop / drawBottom", function()
        it("drawTop removes from index 1", function()
            local deck = {"a", "b", "c"}
            assert.equal("a", util.drawTop(deck))
            assert.equal(2, #deck)
            assert.equal("b", deck[1])
        end)
        it("drawBottom removes the last element", function()
            local deck = {"a", "b", "c"}
            assert.equal("c", util.drawBottom(deck))
            assert.equal(2, #deck)
            assert.equal("b", deck[#deck])
        end)
        it("drawTop returns nil on empty deck", function()
            assert.is_nil(util.drawTop({}))
        end)
        it("drawBottom returns nil on empty deck", function()
            assert.is_nil(util.drawBottom({}))
        end)
    end)

    describe("countCubesOnBoard / cubeSupply", function()
        it("counts 0 on an empty board", function()
            local state = {cubes = {chicago = {modern = {black = 0, blue = 0, yellow = 0, red = 0}}}}
            assert.equal(0, util.countCubesOnBoard(state, "black"))
        end)
        it("counts cubes across all nodes", function()
            local state = {cubes = {
                chicago  = {modern = {black = 2, blue = 0, yellow = 0, red = 0}},
                new_york = {modern = {black = 1, blue = 0, yellow = 0, red = 0}},
            }}
            assert.equal(3, util.countCubesOnBoard(state, "black"))
        end)
        it("cubeSupply = 24 - on-board count", function()
            local state = {cubes = {chicago = {modern = {black = 3, blue = 0, yellow = 0, red = 0}}}}
            assert.equal(21, util.cubeSupply(state, "black"))
        end)
    end)

    describe("instabilityLevel", function()
        local track = {2, 2, 2, 3, 3, 4, 4}
        for i, expected in ipairs(track) do
            it("index " .. i .. " -> " .. expected, function()
                assert.equal(expected, util.instabilityLevel({instabilityIndex = i}))
            end)
        end
    end)

    describe("updateRepaired", function()
        it("marks resolved color repaired when board has 0 cubes of that color", function()
            local state = {
                resolved = {blue = true,  yellow = false, black = false, red = false},
                repaired = {blue = false, yellow = false, black = false, red = false},
                cubes    = {c1 = {p1 = {blue = 0, yellow = 0, black = 0, red = 0}}},
            }
            util.updateRepaired(state)
            assert.is_true(state.repaired.blue)
        end)
        it("does not mark repaired when cubes remain", function()
            local state = {
                resolved = {blue = true,  yellow = false, black = false, red = false},
                repaired = {blue = false, yellow = false, black = false, red = false},
                cubes    = {c1 = {p1 = {blue = 1, yellow = 0, black = 0, red = 0}}},
            }
            util.updateRepaired(state)
            assert.is_false(state.repaired.blue)
        end)
        it("does not mark repaired when not yet resolved", function()
            local state = {
                resolved = {blue = false, yellow = false, black = false, red = false},
                repaired = {blue = false, yellow = false, black = false, red = false},
                cubes    = {c1 = {p1 = {blue = 0, yellow = 0, black = 0, red = 0}}},
            }
            util.updateRepaired(state)
            assert.is_false(state.repaired.blue)
        end)
        it("does not downgrade already-repaired status", function()
            local state = {
                resolved = {blue = true, yellow = false, black = false, red = false},
                repaired = {blue = true, yellow = false, black = false, red = false},
                cubes    = {c1 = {p1 = {blue = 2, yellow = 0, black = 0, red = 0}}},
            }
            util.updateRepaired(state)
            assert.is_true(state.repaired.blue)
        end)
    end)
end)
