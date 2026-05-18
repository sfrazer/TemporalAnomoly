local Save = require("src.persistence.save")

describe("Save", function()

    describe("newProfile", function()
        it("includes a name field defaulting to empty string", function()
            local p = Save.newProfile()
            assert.is_string(p.name)
            assert.equals("", p.name)
        end)

        it("includes instabilityStepDelay defaulting to 5.0", function()
            local p = Save.newProfile()
            assert.is_number(p.instabilityStepDelay)
            assert.equals(5.0, p.instabilityStepDelay)
        end)

        it("includes fullscreen defaulting to false", function()
            local p = Save.newProfile()
            assert.is_false(p.fullscreen)
        end)

        it("includes roleUnlocks as empty table", function()
            local p = Save.newProfile()
            assert.is_table(p.roleUnlocks)
            assert.equals(0, (function() local n=0; for _ in pairs(p.roleUnlocks) do n=n+1 end; return n end)())
        end)

        it("each call returns an independent table", function()
            local a = Save.newProfile()
            local b = Save.newProfile()
            a.name = "Alice"
            assert.equals("", b.name)
        end)
    end)

    describe("serializeState", function()
        it("does not include profile-only fields like name", function()
            local gs = {
                currentCity = "seattle", currentPeriod = "prehistory",
                cubes = {}, outposts = {}, hand = {}, playerDeck = {}, playerDiscard = {},
                threatDeck = {}, threatDiscard = {}, instabilityIndex = 1,
                explosionCount = 0, actionsRemaining = 4, turn = 1,
                resolved = {}, repaired = {}, difficulty = "standard",
                priorityCity = nil, role = "chronologist",
                coordinatorMoveUsed = false, challengeModIds = {},
                teleportBannedTurns = 0, volatileAnomalyActive = false,
                hadDeckUpgrades = false, lost = nil,
            }
            local s = Save.serializeState(gs)
            assert.is_nil(s.name)
            assert.is_nil(s.rpBalance)
            assert.equals("seattle", s.currentCity)
        end)
    end)

end)
