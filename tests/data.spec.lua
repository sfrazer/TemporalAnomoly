local cities  = require("data.cities")
local periods = require("data.periods")
local cards   = require("data.cards")

-- build lookup table used across several tests
local cityById = {}
for _, city in ipairs(cities) do cityById[city.id] = city end

local periodById = {}
for _, p in ipairs(periods) do periodById[p.id] = p end

-- ---------------------------------------------------------------------------
describe("data.cities", function()
    it("has exactly 6 cities", function()
        assert.equal(6, #cities)
    end)

    it("every city has at most 3 connections", function()
        for _, city in ipairs(cities) do
            assert.is_true(
                #city.adjacent <= 3,
                city.name .. " has " .. #city.adjacent .. " connections (max 3)"
            )
        end
    end)

    it("every neighbor id resolves to a known city", function()
        for _, city in ipairs(cities) do
            for _, nid in ipairs(city.adjacent) do
                assert.not_nil(cityById[nid], "Unknown neighbor id '" .. nid .. "' on " .. city.name)
            end
        end
    end)

    it("adjacency is bidirectional (symmetric)", function()
        for _, city in ipairs(cities) do
            for _, nid in ipairs(city.adjacent) do
                local neighbor = cityById[nid]
                local found = false
                for _, backId in ipairs(neighbor.adjacent) do
                    if backId == city.id then found = true; break end
                end
                assert.is_true(found, city.name .. " -> " .. neighbor.name .. " has no return edge")
            end
        end
    end)

    it("all cities form a single connected graph", function()
        local visited = {}
        local queue   = { cities[1].id }
        while #queue > 0 do
            local id = table.remove(queue, 1)
            if not visited[id] then
                visited[id] = true
                for _, nid in ipairs(cityById[id].adjacent) do
                    queue[#queue + 1] = nid
                end
            end
        end
        local count = 0
        for _ in pairs(visited) do count = count + 1 end
        assert.equal(#cities, count, "Graph is not fully connected")
    end)
end)

-- ---------------------------------------------------------------------------
describe("data.periods", function()
    it("has exactly 4 periods", function()
        assert.equal(4, #periods)
    end)

    it("maps each period to the correct color", function()
        assert.equal("blue",   periodById["prehistory"].color)
        assert.equal("yellow", periodById["industrial"].color)
        assert.equal("black",  periodById["modern"].color)
        assert.equal("red",    periodById["far_future"].color)
    end)

    it("all four colors are present", function()
        local colors = {}
        for _, p in ipairs(periods) do colors[p.color] = true end
        assert.is_true(colors["blue"]   and colors["yellow"]
                    and colors["black"] and colors["red"])
    end)
end)

-- ---------------------------------------------------------------------------
describe("data.cards", function()
    describe("city cards", function()
        it("has exactly 48 city cards (6 cities × 4 periods × 2 copies)", function()
            assert.equal(48, #cards.cityCards)
        end)

        it("has exactly 2 copies of every (city, period) pair", function()
            local counts = {}
            for _, card in ipairs(cards.cityCards) do
                local key = card.city .. ":" .. card.period
                counts[key] = (counts[key] or 0) + 1
            end
            -- 6 × 4 = 24 unique pairs
            local pairs_count = 0
            for _, n in pairs(counts) do
                pairs_count = pairs_count + 1
                assert.equal(2, n)
            end
            assert.equal(24, pairs_count)
        end)

        it("every city card color matches its period color", function()
            for _, card in ipairs(cards.cityCards) do
                assert.equal(
                    periodById[card.period].color, card.color,
                    "Color mismatch on " .. card.name
                )
            end
        end)

        it("every city card references a known city and period", function()
            for _, card in ipairs(cards.cityCards) do
                assert.not_nil(cityById[card.city],   "Unknown city '"   .. card.city   .. "'")
                assert.not_nil(periodById[card.period], "Unknown period '" .. card.period .. "'")
            end
        end)
    end)

    describe("event cards", function()
        it("has exactly 4 base event cards", function()
            assert.equal(4, #cards.eventCards)
        end)

        it("contains all required event ids", function()
            local ids = {}
            for _, c in ipairs(cards.eventCards) do ids[c.id] = true end
            assert.is_true(ids["one_quiet_night"],      "Missing one_quiet_night")
            assert.is_true(ids["government_grant"],     "Missing government_grant")
            assert.is_true(ids["temporal_slip"],        "Missing temporal_slip")
            assert.is_true(ids["resilient_population"], "Missing resilient_population")
        end)
    end)

    describe("flux card", function()
        it("flux card template is defined with correct type", function()
            assert.is_table(cards.fluxCard)
            assert.equal("flux", cards.fluxCard.type)
            assert.equal("chronological_flux", cards.fluxCard.id)
        end)
    end)

    describe("threat cards", function()
        it("has exactly 24 threat cards (6 cities × 4 periods)", function()
            assert.equal(24, #cards.threatCards)
        end)

        it("each (city, period) pair appears exactly once", function()
            local seen = {}
            for _, card in ipairs(cards.threatCards) do
                local key = card.city .. ":" .. card.period
                assert.is_nil(seen[key], "Duplicate threat card: " .. key)
                seen[key] = true
            end
        end)

        it("every threat card color matches its period", function()
            for _, card in ipairs(cards.threatCards) do
                assert.equal(
                    periodById[card.period].color, card.color,
                    "Color mismatch on threat card " .. card.name
                )
            end
        end)

        it("every threat card references a known city and period", function()
            for _, card in ipairs(cards.threatCards) do
                assert.not_nil(cityById[card.city],     "Unknown city '"   .. card.city   .. "'")
                assert.not_nil(periodById[card.period], "Unknown period '" .. card.period .. "'")
            end
        end)
    end)
end)
