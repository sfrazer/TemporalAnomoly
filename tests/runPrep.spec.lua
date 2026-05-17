local RunPrep   = require("src.rules.runPrep")
local GameState = require("src.state.gameState")
local Mod       = require("src.state.modifiers")
local H         = require("tests.helpers")

local function makeProfile(overrides)
    local p = {
        rpBalance       = 999,
        bonusSelections = {},
        deckSelections  = {},
        challengeModIds = {},
    }
    if overrides then for k, v in pairs(overrides) do p[k] = v end end
    return p
end

describe("RunPrep", function()

    before_each(function() Mod.clear() end)

    -- -------------------------------------------------------------------------
    describe("computeRP", function()
        it("+1 for attempting even on loss", function()
            local gs = H.makeState()
            gs.difficulty = "introductory"
            gs.lost = "timeout"
            assert.equal(1, RunPrep.computeRP(gs, {}))
        end)

        it("+3 bonus for winning", function()
            local gs = H.makeState()
            gs.difficulty = "introductory"
            assert.equal(4, RunPrep.computeRP(gs, {}))
        end)

        it("+2 per REPAIRED anomaly", function()
            local gs = H.makeState()
            gs.difficulty = "introductory"
            gs.repaired.blue   = true
            gs.repaired.yellow = true
            assert.equal(8, RunPrep.computeRP(gs, {}))  -- 1 + 3 + 2 + 2
        end)

        it("difficulty tier bonus: standard +1, heroic +2, legendary +3", function()
            local gs = H.makeState()
            gs.difficulty = "standard"
            assert.equal(5, RunPrep.computeRP(gs, {}))
            gs.difficulty = "heroic"
            assert.equal(6, RunPrep.computeRP(gs, {}))
            gs.difficulty = "legendary"
            assert.equal(7, RunPrep.computeRP(gs, {}))
        end)

        it("introductory gives no difficulty bonus", function()
            local gs = H.makeState()
            gs.difficulty = "introductory"
            assert.equal(4, RunPrep.computeRP(gs, {}))
        end)

        it("awards bonus RP for each challenge mod in play", function()
            local gs = H.makeState()
            gs.difficulty = "introductory"
            -- hotspot=1, cascade_event=2 → bonus 3
            assert.equal(7, RunPrep.computeRP(gs, {"hotspot", "cascade_event"}))
        end)

        it("combines all bonuses", function()
            local gs = H.makeState()
            gs.difficulty = "standard"
            gs.repaired.red = true
            -- 1 attempt + 3 win + 2 repaired + 1 standard + 3 volatile_anomaly = 10
            assert.equal(10, RunPrep.computeRP(gs, {"volatile_anomaly"}))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("totalCost", function()
        it("returns 0 for empty selections", function()
            assert.equal(0, RunPrep.totalCost({}, {}))
        end)

        it("costs 3 RP per extra starting card", function()
            assert.equal(3,  RunPrep.totalCost({extra_starting_card = 1}, {}))
            assert.equal(6,  RunPrep.totalCost({extra_starting_card = 2}, {}))
            assert.equal(9,  RunPrep.totalCost({extra_starting_card = 3}, {}))
        end)

        it("costs for deck cards", function()
            assert.equal(3, RunPrep.totalCost({}, {stabilizer_cache = 1}))
            assert.equal(6, RunPrep.totalCost({}, {stabilizer_cache = 2}))
        end)

        it("sums bonus and deck costs together", function()
            -- extra_starting_card=3, mobile_outpost=4 → 7
            assert.equal(7, RunPrep.totalCost({extra_starting_card = 1}, {mobile_outpost = 1}))
        end)

        it("challenge mods are free (not counted)", function()
            assert.equal(0, RunPrep.totalCost({}, {}))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("prepOpts", function()
        it("base profile produces default opts", function()
            local opts = RunPrep.prepOpts(makeProfile(), "chronologist")
            assert.equal("chronologist", opts.role)
            assert.equal(4,              opts.handSize)
            assert.equal(0,              opts.skipSeedingCount)
            assert.equal(0,              opts.removeFluxCount)
            assert.equal(0,              opts.bonusActions)
            assert.is_false(             opts.startingOutpost)
            assert.equal(0,              #opts.extraDeckCards)
            assert.equal(0,              #opts.challengeModIds)
        end)

        it("stacks extra starting card hand size", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {extra_starting_card = 2}}), "chronologist")
            assert.equal(6, opts.handSize)
        end)

        it("sets skipSeedingCount for light_incidents", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {light_incidents = 1}}), "chronologist")
            assert.equal(2, opts.skipSeedingCount)
        end)

        it("sets removeFluxCount for remove_flux", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {remove_flux = 1}}), "chronologist")
            assert.equal(1, opts.removeFluxCount)
        end)

        it("sets bonusActions for bonus_action", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {bonus_action = 1}}), "chronologist")
            assert.equal(1, opts.bonusActions)
        end)

        it("sets startingOutpost for starting_outpost", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {starting_outpost = 1}}), "chronologist")
            assert.is_true(opts.startingOutpost)
        end)

        it("builds extraDeckCards from deckSelections", function()
            local opts = RunPrep.prepOpts(makeProfile({
                deckSelections = {stabilizer_cache = 2, supply_drop = 1}
            }), "chronologist")
            assert.equal(3, #opts.extraDeckCards)
            assert.equal("event", opts.extraDeckCards[1].type)
        end)

        it("passes challenge mod ids through", function()
            local opts = RunPrep.prepOpts(makeProfile({
                challengeModIds = {"hotspot", "temporal_ban"}
            }), "chronologist")
            assert.equal(2, #opts.challengeModIds)
            assert.equal("hotspot",     opts.challengeModIds[1])
            assert.equal("temporal_ban", opts.challengeModIds[2])
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("applyModifiers", function()
        it("registers bonus action hook when bonusActions > 0", function()
            RunPrep.applyModifiers({bonusActions = 1})
            assert.equal(5, Mod.actionsPerTurn(H.makeState()))
        end)

        it("no-ops when bonusActions is 0", function()
            RunPrep.applyModifiers({bonusActions = 0})
            assert.equal(4, Mod.actionsPerTurn(H.makeState()))
        end)
    end)

    -- -------------------------------------------------------------------------
    describe("GameState integration", function()
        it("applies extra hand size", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {extra_starting_card = 2}}), "chronologist")
            local gs = GameState.new(opts)
            assert.equal(6, #gs.hand)
        end)

        it("places starting outpost in starting city", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {starting_outpost = 1}}), "chronologist")
            local gs = GameState.new(opts)
            assert.is_true(gs.outposts["atlanta"])
        end)

        it("light incidents reduces cubes seeded", function()
            local opts = RunPrep.prepOpts(makeProfile({bonusSelections = {light_incidents = 1}}), "chronologist")
            local gs = GameState.new(opts)
            local util = require("src.util")
            local total = 0
            for _, cityData in pairs(gs.cubes) do
                for _, periodData in pairs(cityData) do
                    for _, color in ipairs(util.COLORS) do
                        total = total + (periodData[color] or 0)
                    end
                end
            end
            assert.equal(6, total)  -- skip first 2 seedings (3+3), leaving 2+2+1+1=6
        end)

        it("adds extra deck cards into player deck + hand pool", function()
            local opts = RunPrep.prepOpts(makeProfile({
                deckSelections = {stabilizer_cache = 2, supply_drop = 1}
            }), "chronologist")
            local gs = GameState.new(opts)
            local eventCount = 0
            for _, c in ipairs(gs.hand) do
                if c.type == "event" then eventCount = eventCount + 1 end
            end
            for _, c in ipairs(gs.playerDeck) do
                if c.type == "event" then eventCount = eventCount + 1 end
            end
            assert.equal(7, eventCount)  -- 4 base + 3 extra
        end)

        it("challenge mod cards appear in threat deck (not discard)", function()
            local opts = RunPrep.prepOpts(makeProfile({
                challengeModIds = {"hotspot", "temporal_ban"}
            }), "chronologist")
            local gs = GameState.new(opts)
            local modCount = 0
            for _, c in ipairs(gs.threatDeck) do
                if c.type == "challengemod" then modCount = modCount + 1 end
            end
            assert.equal(2, modCount)
        end)

        it("remove_flux reduces flux card count", function()
            -- standard has 5 flux; removing 1 → 4
            local optsBase    = {difficulty = "standard", role = "chronologist"}
            local optsRemoved = RunPrep.prepOpts(makeProfile({bonusSelections = {remove_flux = 1}}), "chronologist")
            optsRemoved.difficulty = "standard"

            local function countFlux(gs)
                local n = 0
                for _, c in ipairs(gs.playerDeck) do if c.type == "flux" then n = n + 1 end end
                return n
            end

            local gsBase    = GameState.new(optsBase)
            local gsRemoved = GameState.new(optsRemoved)
            assert.equal(5, countFlux(gsBase))
            assert.equal(4, countFlux(gsRemoved))
        end)
    end)

end)
