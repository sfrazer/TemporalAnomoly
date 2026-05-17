local GameState     = require("src.state.gameState")
local Actions       = require("src.rules.actions")
local Phases        = require("src.rules.phases")
local WinLose       = require("src.rules.winLose")
local Mod           = require("src.state.modifiers")
local Roles         = require("src.rules.roles")
local RunPrep       = require("src.rules.runPrep")
local Save          = require("src.persistence.save")
local AutoSave      = require("src.persistence.autosave")

local Unlocks       = require("src.rules.unlocks")
local Flux          = require("src.rules.flux")
local Explosion     = require("src.rules.explosion")
local Console       = require("src.debug.console")
local Tooltip       = require("src.ui.tooltip")
local Anim          = require("src.ui.anim")
local Sounds        = require("src.audio.sounds")

local Map              = require("src.ui.map")
local Hand             = require("src.ui.hand")
local UIActions        = require("src.ui.actions")
local Footer           = require("src.ui.footer")
local Modals           = require("src.ui.modals")
local RoleSelect       = require("src.ui.roleSelect")
local ProfileSelect    = require("src.ui.profileSelect")
local MetaShop         = require("src.ui.metaShop")
local DifficultySelect = require("src.ui.difficultySelect")
local GameOver         = require("src.ui.gameOver")

-- ---------------------------------------------------------------------------
-- Layout (virtual 1280×720)
-- ---------------------------------------------------------------------------
local VIRTUAL_W = 1280
local VIRTUAL_H = 720

local LAYOUT = {
    mapY     = 0,   mapH     = 540,
    actY     = 540, actH     = 54,
    handY    = 594, handH    = 76,
    footerY  = 670, footerH  = 50,
}

-- ---------------------------------------------------------------------------
-- Game state
-- ---------------------------------------------------------------------------
local gs                -- GameState table
local modal             -- active Modals.new() table, or nil
local activeBtn         -- currently highlighted action button id
local selectedCard      -- index into gs.hand, or nil
local message           -- {text, ttl} for brief feedback messages
local phase             -- "profileselect"|"setup"|"difficulty"|"shop"|"action"|"gameover"
local gameResult        -- {result, reason, earnedRP, newUnlocks}
local profilesCache     -- [slot] = profile_table_or_nil, used by profileselect
local selectedRole      -- role id chosen on role-select screen, held until shop commits
local selectedDifficulty -- difficulty id chosen before shop, held until commitShop
local shopState         -- pending shop selections {bonusSelections, deckSelections, challengeModIds}
local initAnims         -- forward declaration; defined below action handlers
local handleCardPlay    -- forward declaration; defined alongside initAnims

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function toVirtual(sx, sy)
    local ww, wh   = love.graphics.getDimensions()
    local scale    = math.min(ww/VIRTUAL_W, wh/VIRTUAL_H)
    local ox, oy   = (ww - VIRTUAL_W*scale)/2, (wh - VIRTUAL_H*scale)/2
    return (sx - ox)/scale, (sy - oy)/scale
end

local function showMsg(text, duration)
    message = {text = text, ttl = duration or 2.5}
end

local function endAction()
    activeBtn    = nil
    selectedCard = nil
    modal        = nil
    local result, reason = WinLose.checkWinLose(gs)
    if result then
        phase = "gameover"
        local earnedRP = RunPrep.computeRP(gs, gs.challengeModIds or {})
        local slot     = AutoSave.getSlot()
        local profile  = AutoSave.getProfile()
        local newUnlocks = {}
        if profile then
            profile.rpBalance = (profile.rpBalance or 0) + earnedRP
            if result == "won" then
                newUnlocks = Unlocks.evaluateUnlocks(gs, profile)
                Unlocks.applyUnlocks(profile, newUnlocks)
            end
            Save.saveProfile(slot, profile)
        end
        gameResult = {result = result, reason = reason, earnedRP = earnedRP, newUnlocks = newUnlocks}
        if result == "won" then Sounds.win() else Sounds.lose() end
        AutoSave.finish()
        -- Re-init so the profile (now with updated RP and no activeRun) stays
        -- accessible for Return to Shop / Play Again flows.
        if slot and profile then AutoSave.init(slot, profile) end
    else
        AutoSave.save(gs)
    end
end

local function advancePhase()
    if phase == "action" then
        Anim.phaseBanner("Draw Phase", 0)
        phase = "draw"
        Phases.runDrawPhase(gs)
        if gs.lost then endAction(); return end
        Anim.phaseBanner("Instability Phase", 0.70)
        phase = "instability"
        Phases.runInstabilityPhase(gs)
        gs.sealedCity = nil
        if gs.lost then endAction(); return end
        phase = "action"
        gs.actionsRemaining    = Mod.actionsPerTurn(gs)
        gs.coordinatorMoveUsed = false
        if (gs.teleportBannedTurns or 0) > 0 then
            gs.teleportBannedTurns = gs.teleportBannedTurns - 1
        end
        gs.turn = gs.turn + 1
    end
    endAction()
end

local function enterProfileSelect()
    profilesCache = {}
    for slot = 1, Save.SLOT_COUNT do
        profilesCache[slot] = Save.loadProfile(slot)
    end
    phase      = "profileselect"
    gs         = nil
    modal      = nil
    activeBtn  = nil
    message    = nil
    gameResult = nil
end

local function resumeGame(runData, slot, profile)
    Mod.clear()
    initAnims()
    gs = runData
    Roles.applyRole(gs, gs.role)
    RunPrep.applyModifiers(RunPrep.prepOpts(profile or Save.newProfile(), gs.role))
    AutoSave.init(slot, profile)
    phase      = "action"
    modal      = nil
    activeBtn  = nil
    message    = nil
    gameResult = nil
    Map.setMapHeight(LAYOUT.mapH)
end

local function startGame(roleId)
    local slot    = AutoSave.getSlot()
    local profile = AutoSave.getProfile()
    Mod.clear()
    initAnims()
    local opts = RunPrep.prepOpts(profile or Save.newProfile(), roleId)
    gs = GameState.new(opts)
    Roles.applyRole(gs, roleId)
    RunPrep.applyModifiers(opts)
    gs.actionsRemaining = Mod.actionsPerTurn(gs)
    if profile then profile.lastRole = roleId end
    AutoSave.init(slot, profile)
    AutoSave.save(gs)
    phase      = "action"
    modal      = nil
    activeBtn  = nil
    message    = nil
    gameResult = nil
    Map.setMapHeight(LAYOUT.mapH)
end

local function enterDifficulty(roleId)
    selectedRole = roleId
    phase = "difficulty"
end

local function enterShop(difficulty)
    selectedDifficulty = difficulty
    local profile = AutoSave.getProfile()
    if profile then
        profile.selectedDifficulty = difficulty
        Save.saveProfile(AutoSave.getSlot(), profile)
    end
    shopState = {bonusSelections = {}, deckSelections = {}, challengeModIds = {}}
    if profile then
        for k, v in pairs(profile.bonusSelections or {}) do shopState.bonusSelections[k] = v end
        for k, v in pairs(profile.deckSelections  or {}) do shopState.deckSelections[k]  = v end
        for _, v in ipairs(profile.challengeModIds or {}) do
            shopState.challengeModIds[#shopState.challengeModIds + 1] = v
        end
    end
    phase = "shop"
end

local function commitShop()
    local profile = AutoSave.getProfile()
    if not profile then return end
    local cost = RunPrep.totalCost(shopState.bonusSelections, shopState.deckSelections)
    if cost > (profile.rpBalance or 0) then
        showMsg("Not enough RP"); return
    end
    profile.bonusSelections = shopState.bonusSelections
    profile.deckSelections  = shopState.deckSelections
    profile.challengeModIds = shopState.challengeModIds
    Save.saveProfile(AutoSave.getSlot(), profile)
    startGame(selectedRole)
end

local function selectProfile(slot)
    local profile = profilesCache[slot]
    if not profile then
        profile = Save.newProfile()
        Save.saveProfile(slot, profile)
        profilesCache[slot] = profile
    end
    if profile.activeRun then
        resumeGame(profile.activeRun, slot, profile)
    else
        AutoSave.init(slot, profile)
        phase = "setup"
    end
end

-- ---------------------------------------------------------------------------
-- Action handling
-- ---------------------------------------------------------------------------
local COLOR_ITEMS = {
    {label = "Blue (Prehistory)",    value = "blue"},
    {label = "Yellow (Industrial)",  value = "yellow"},
    {label = "Black (Modern)",       value = "black"},
    {label = "Red (Far Future)",     value = "red"},
}

local PERIOD_ITEMS = {
    {label = "Prehistory",    value = "prehistory"},
    {label = "Industrial Age",value = "industrial"},
    {label = "Modern Age",    value = "modern"},
    {label = "Far Future",    value = "far_future"},
}

local cityItems = {}
do
    local cities = require("data.cities")
    for _, c in ipairs(cities) do
        cityItems[#cityItems+1] = {label = c.name, value = c.id}
    end
end

local function spendAction(fn)
    local ok, err = fn()
    if ok then
        gs.actionsRemaining = gs.actionsRemaining - 1
        if gs.actionsRemaining <= 0 then advancePhase() end
        endAction()
    else
        showMsg(err or "Action failed")
        activeBtn = nil
    end
end

local function handleButtonClick(id)
    if phase ~= "action" then showMsg("Not your action phase"); return end
    activeBtn = id
    Sounds.buttonClick()

    if id == "end_turn" then
        advancePhase()
        return
    end

    if id == "build" then
        spendAction(function() return Actions.tryBuildOutpost(gs) end)
        return
    end

    if id == "clear" then
        local node = gs.cubes[gs.currentCity][gs.currentPeriod]
        local present = {}
        for _, item in ipairs(COLOR_ITEMS) do
            if (node[item.value] or 0) > 0 then
                present[#present + 1] = item
            end
        end
        if #present > 1 then
            modal = Modals.new("Clear which anomaly color?", present, function(color)
                spendAction(function() return Actions.tryClear(gs, color) end)
            end)
        else
            spendAction(function() return Actions.tryClear(gs) end)
        end
        return
    end

    if id == "resolve" then
        modal = Modals.new("Resolve which anomaly color?", COLOR_ITEMS, function(color)
            spendAction(function() return Actions.tryResolve(gs, color) end)
        end)
        return
    end

    if id == "travel" then
        showMsg("Click a city node to travel there")
        -- activeBtn stays set; map click will resolve
        return
    end

    if id == "teleport" then
        showMsg("Click a city node to teleport (uses matching card from hand)")
        return
    end

    if id == "coordinator_move" then
        showMsg("Click a city with a Temporal Outpost to move there for free")
        return
    end

    if id == "teleport_alt" then
        modal = Modals.new("Discard current-city card and go where?", cityItems, function(destCity)
            modal = Modals.new("Which time period?", PERIOD_ITEMS, function(destPeriod)
                spendAction(function() return Actions.tryTeleportAlt(gs, destCity, destPeriod) end)
            end)
        end)
        return
    end

    if id == "retrieve_card" then
        local eventItems = {}
        for i, c in ipairs(gs.playerDiscard) do
            if c.type == "event" then
                eventItems[#eventItems + 1] = {label = c.name, value = i}
            end
        end
        if #eventItems == 0 then
            showMsg("No event cards in discard")
            activeBtn = nil
            return
        end
        modal = Modals.new("Retrieve which event card?", eventItems, function(idx)
            local ok, err = Actions.tryRetrieveCard(gs, idx)
            if ok then
                showMsg("Card returned to hand")
                endAction()
            else
                showMsg(err or "Cannot retrieve")
            end
        end)
        return
    end

    if id == "peek_threat" then
        local items = {}
        for i = 1, math.min(2, #gs.threatDeck) do
            local card = gs.threatDeck[#gs.threatDeck - i + 1]
            items[#items + 1] = {label = card.name or card.id, value = i}
        end
        -- Spend the action first; endAction() inside spendAction clears modal,
        -- so the modal must be opened AFTER spendAction returns.
        spendAction(function() return true end)
        -- Only show result if the game is still in the action phase (last-action
        -- peek would trigger phases; items built pre-phase are intentionally stale).
        if phase == "action" then
            if #items > 0 then
                modal = Modals.new("Top of Threat Deck:", items, function() end)
            else
                showMsg("Threat deck is empty")
            end
        end
        return
    end
end

local function handleMapClick(vx, vy)
    local hit = Map.hitCity(vx, vy)
    if not hit then return end

    if activeBtn == "travel" then
        spendAction(function() return Actions.tryTravel(gs, hit.city, hit.period) end)
    elseif activeBtn == "teleport" then
        spendAction(function() return Actions.tryTeleport(gs, hit.city, hit.period) end)
    elseif activeBtn == "coordinator_move" then
        local ok, err = Actions.tryCoordinatorMove(gs, hit.city)
        if ok then
            endAction()
        else
            showMsg(err or "Cannot move there")
            activeBtn = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- Animation event hooks (re-registered after every Mod.clear())
-- ---------------------------------------------------------------------------
initAnims = function()
    Mod.register("canPlaceCube", function(state, city, period, color)
        if state.sealedCity and city == state.sealedCity then return false end
    end)
    Mod.register("onCubePlaced", function(state, ctx)
        local wx, wy = Map.getNodeWorld(ctx.city, ctx.period)
        if wx then
            local vx, vy = Map.worldToVirtual(wx, wy)
            Anim.cubePlaced(vx, vy, ctx.color)
        end
        Sounds.cubePlaced()
    end)
    Mod.register("onTemporalExplosion", function(state, ctx)
        local wx, wy = Map.getNodeWorld(ctx.city, ctx.period)
        if wx then
            local vx, vy = Map.worldToVirtual(wx, wy)
            Anim.explosion(vx, vy)
        end
        Sounds.explosion()
    end)
    Mod.register("onChronologicalFlux", function()
        Anim.fluxPulse()
        Sounds.flux()
    end)
end

-- ---------------------------------------------------------------------------
-- Card play flow
-- ---------------------------------------------------------------------------
handleCardPlay = function(card, cardIdx)
    local id = card.id

    -- No-modal cards
    if id == "paradox_barrier" or id == "time_corridor" or
       id == "mobile_outpost"  or id == "supply_drop" then
        local ok, err = Actions.tryPlayCard(gs, cardIdx)
        selectedCard = nil
        if ok then
            showMsg(card.name .. " played")
            endAction()
        else
            showMsg(err or "Cannot play card")
        end
        return
    end

    -- Unknown Assistance: city picker
    if id == "unknown_assistance" then
        modal = Modals.new("Build Outpost in which city?", cityItems, function(cityId)
            local ok, err = Actions.tryPlayCard(gs, cardIdx, cityId)
            selectedCard = nil
            if ok then
                showMsg("Temporal Outpost built in " .. cityId)
                endAction()
            else
                showMsg(err or "Cannot play card")
            end
        end)
        return
    end

    -- Temporal Slip: city picker → period picker
    if id == "temporal_slip" then
        modal = Modals.new("Slip to which city?", cityItems, function(cityId)
            modal = Modals.new("Which time period?", PERIOD_ITEMS, function(periodId)
                local ok, err = Actions.tryPlayCard(gs, cardIdx, cityId, periodId)
                selectedCard = nil
                if ok then
                    showMsg("Slipped to " .. cityId)
                    endAction()
                else
                    showMsg(err or "Cannot play card")
                end
            end)
        end)
        return
    end

    -- Chrono Lock: pick card from threat discard to permanently remove
    if id == "chrono_lock" then
        if #gs.threatDiscard == 0 then
            showMsg("Threat discard is empty")
            selectedCard = nil
            return
        end
        local items = {}
        for i, c in ipairs(gs.threatDiscard) do
            items[#items + 1] = {label = c.name or c.id, value = i}
        end
        modal = Modals.new("Remove which threat card permanently?", items, function(idx)
            local ok, err = Actions.tryPlayCard(gs, cardIdx, idx)
            selectedCard = nil
            if ok then
                showMsg("Threat card permanently removed")
                endAction()
            else
                showMsg(err or "Cannot play card")
            end
        end)
        return
    end

    -- Chronological Rewind: color picker
    if id == "chronological_rewind" then
        modal = Modals.new("Clear which anomaly color from " .. gs.currentCity .. "?",
            COLOR_ITEMS, function(color)
                local ok, err = Actions.tryPlayCard(gs, cardIdx, color)
                selectedCard = nil
                if ok then
                    showMsg("All " .. color .. " cubes cleared from " .. gs.currentCity)
                    endAction()
                else
                    showMsg(err or "Cannot play card")
                end
            end)
        return
    end

    -- Temporal Seal: city picker
    if id == "temporal_seal" then
        modal = Modals.new("Seal which city against incidents?", cityItems, function(cityId)
            local ok, err = Actions.tryPlayCard(gs, cardIdx, cityId)
            selectedCard = nil
            if ok then
                showMsg(cityId .. " sealed until next Instability Phase")
                endAction()
            else
                showMsg(err or "Cannot play card")
            end
        end)
        return
    end

    showMsg("This card has no effect yet")
    selectedCard = nil
end

-- ---------------------------------------------------------------------------
-- Debug console commands (closures capture gs, phase, endAction, etc.)
-- ---------------------------------------------------------------------------
local function initConsole()
    local util = require("src.util")

    Console.register("help", function()
        Console.print("flux                         — force a Chronological Flux")
        Console.print("seed <n>                     — run instability phase n times")
        Console.print("addcube <city> <period> <color>")
        Console.print("clearcube <city> <period> <color>")
        Console.print("setinstability <n>           — jump instability index (1-7)")
        Console.print("showplayerdeck               — list player deck in draw order")
        Console.print("showthreatdeck               — list threat deck in draw order")
        Console.print("win                          — force a win")
        Console.print("lose                         — force a loss")
        Console.print("dump                         — print key state values")
    end)

    Console.register("flux", function()
        if not gs then return "No active game" end
        Flux.resolveChronologicalFlux(gs)
        endAction()
        return "Chronological Flux resolved"
    end)

    Console.register("seed", function(args)
        if not gs then return "No active game" end
        local n = math.max(1, math.floor(tonumber(args[2]) or 1))
        for _ = 1, n do
            Phases.runInstabilityPhase(gs)
        end
        endAction()
        return "Ran instability phase " .. n .. "x"
    end)

    Console.register("addcube", function(args)
        if not gs then return "No active game" end
        local city, period, color = args[2], args[3], args[4]
        if not (city and period and color) then
            return "Usage: addcube <city> <period> <color>"
        end
        if not (gs.cubes[city] and gs.cubes[city][period]) then
            return "Unknown city/period: " .. (city or "?") .. "/" .. (period or "?")
        end
        Explosion.placeCubesAt(gs, city, period, color, 1)
        endAction()
        return "Added " .. color .. " cube at " .. city .. "/" .. period
    end)

    Console.register("clearcube", function(args)
        if not gs then return "No active game" end
        local city, period, color = args[2], args[3], args[4]
        if not (city and period and color) then
            return "Usage: clearcube <city> <period> <color>"
        end
        local node = gs.cubes[city] and gs.cubes[city][period]
        if not node then
            return "Unknown city/period: " .. (city or "?") .. "/" .. (period or "?")
        end
        node[color] = math.max(0, (node[color] or 0) - 1)
        util.updateRepaired(gs)
        endAction()
        return "Removed " .. color .. " cube from " .. city .. "/" .. period
    end)

    Console.register("setinstability", function(args)
        if not gs then return "No active game" end
        local n = tonumber(args[2])
        if not n then return "Usage: setinstability <n>" end
        gs.instabilityIndex = math.max(1, math.min(7, math.floor(n)))
        return "Instability index → " .. gs.instabilityIndex
    end)

    Console.register("showplayerdeck", function()
        if not gs then return "No active game" end
        Console.print("Player deck (" .. #gs.playerDeck .. " cards, index 1 = top):")
        for i, c in ipairs(gs.playerDeck) do
            local detail = c.type == "city" and (c.city .. "/" .. c.period) or (c.type or "?")
            Console.print(i .. ": " .. (c.name or c.id or "?") .. " [" .. detail .. "]")
        end
    end)

    Console.register("showthreatdeck", function()
        if not gs then return "No active game" end
        Console.print("Threat deck (" .. #gs.threatDeck .. " cards, index 1 = top):")
        for i, c in ipairs(gs.threatDeck) do
            local detail = c.city and (c.city .. "/" .. c.period) or (c.id or "?")
            Console.print(i .. ": " .. (c.name or c.id or "?") .. " [" .. detail .. "]")
        end
    end)

    Console.register("win", function()
        if not gs then return "No active game" end
        gs.resolved = {blue = true, yellow = true, black = true, red = true}
        util.updateRepaired(gs)
        endAction()
    end)

    Console.register("lose", function()
        if not gs then return "No active game" end
        gs.lost = "debug: forced loss"
        endAction()
    end)

    Console.register("dump", function()
        if not gs then return "No active game" end
        Console.print("city=" .. gs.currentCity .. "  period=" .. gs.currentPeriod)
        Console.print("turn=" .. gs.turn .. "  actions=" .. gs.actionsRemaining ..
                       "  instability=" .. gs.instabilityIndex)
        Console.print("difficulty=" .. gs.difficulty .. "  role=" .. (gs.role or "?"))
        Console.print("explosions=" .. gs.explosionCount)
        local res = {}
        for _, c in ipairs({"blue","yellow","black","red"}) do
            if gs.resolved[c] then res[#res+1] = c end
        end
        Console.print("resolved=[" .. table.concat(res, ",") .. "]")
        local rep = {}
        for _, c in ipairs({"blue","yellow","black","red"}) do
            if gs.repaired[c] then rep[#rep+1] = c end
        end
        Console.print("repaired=[" .. table.concat(rep, ",") .. "]")
        if gs.priorityCity then
            Console.print("priorityCity=" .. gs.priorityCity)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Love2D callbacks
-- ---------------------------------------------------------------------------
function love.load()
    math.randomseed(os.time())
    Map.setMapHeight(LAYOUT.mapH)
    initConsole()

    -- Try to resume the last session automatically
    local index = Save.loadIndex()
    if index.lastUsed then
        local profile = Save.loadProfile(index.lastUsed)
        if profile and profile.activeRun then
            resumeGame(profile.activeRun, index.lastUsed, profile)
            return
        end
    end

    enterProfileSelect()
end

function love.update(dt)
    if message and message.ttl > 0 then
        message.ttl = message.ttl - dt
        if message.ttl <= 0 then message = nil end
    end
    Anim.update(dt)
    Console.update(dt)
end

function love.draw()
    local ww, wh   = love.graphics.getDimensions()
    local scale    = math.min(ww/VIRTUAL_W, wh/VIRTUAL_H)
    local ox, oy   = (ww - VIRTUAL_W*scale)/2, (wh - VIRTUAL_H*scale)/2

    -- Letterbox background
    love.graphics.setColor(0.03, 0.03, 0.04)
    love.graphics.rectangle("fill", 0, 0, ww, wh)

    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale, scale)
    local shakeX, shakeY = Anim.getShakeOffset()
    if shakeX ~= 0 or shakeY ~= 0 then
        love.graphics.translate(shakeX, shakeY)
    end

    if phase == "profileselect" then
        ProfileSelect.render(profilesCache or {})
        love.graphics.pop()
        return
    end

    if phase == "setup" then
        RoleSelect.render(AutoSave.getProfile())
        love.graphics.pop()
        return
    end

    if phase == "difficulty" then
        DifficultySelect.render()
        love.graphics.pop()
        return
    end

    if phase == "shop" then
        local profile = AutoSave.getProfile()
        MetaShop.render(shopState, profile and profile.rpBalance or 0)
        local diffLabel = (selectedDifficulty or "standard"):gsub("^%l", string.upper)
        love.graphics.setColor(0.60, 0.62, 0.72)
        love.graphics.printf("Difficulty: " .. diffLabel, 0, 42, VIRTUAL_W, "center")
        love.graphics.pop()
        return
    end

    Map.render(gs)
    UIActions.render(LAYOUT.actY, LAYOUT.actH, activeBtn, gs)
    Hand.render(gs, LAYOUT.handY, selectedCard)
    Footer.render(gs, LAYOUT.footerY, LAYOUT.footerH)
    Modals.render(modal)

    -- Feedback message
    if message then
        local alpha = math.min(1, message.ttl)
        love.graphics.setColor(0.05, 0.05, 0.08, alpha * 0.85)
        love.graphics.rectangle("fill", 340, 256, 600, 48, 6)
        love.graphics.setColor(1, 1, 1, alpha)
        local font = love.graphics.getFont()
        local tw = font:getWidth(message.text)
        love.graphics.print(message.text, 640 - tw/2, 268)
    end

    -- Game over overlay
    if phase == "gameover" then
        GameOver.render(gameResult)
    end

    -- Actions remaining indicator
    if phase == "action" then
        love.graphics.setColor(0.5, 0.6, 0.8, 0.7)
        love.graphics.printf("Actions: " .. tostring(gs.actionsRemaining), 0, LAYOUT.actY - 20, VIRTUAL_W, "right")
    end

    Anim.render()
    if modal then Tooltip.suppress() end
    Tooltip.render()
    Console.render()

    love.graphics.pop()
end

function love.textinput(text)
    Console.textinput(text)
end

function love.mousepressed(sx, sy, button)
    local vx, vy = toVirtual(sx, sy)

    -- Profile selection screen
    if phase == "profileselect" then
        if button == 1 then
            local hit = ProfileSelect.hit(vx, vy)
            if hit then
                if hit.action == "delete" and profilesCache[hit.slot] then
                    Save.deleteProfile(hit.slot)
                    profilesCache[hit.slot] = nil
                elseif hit.action == "select" then
                    selectProfile(hit.slot)
                end
            end
        end
        return
    end

    -- Role selection screen
    if phase == "setup" then
        if button == 1 then
            local roleId = RoleSelect.hit(vx, vy, AutoSave.getProfile())
            if roleId then enterDifficulty(roleId) end
        end
        return
    end

    -- Difficulty selection screen
    if phase == "difficulty" then
        if button == 1 then
            local difficulty = DifficultySelect.hit(vx, vy)
            if difficulty then enterShop(difficulty) end
        end
        return
    end

    -- Shop screen
    if phase == "shop" then
        if button == 1 then
            local profile = AutoSave.getProfile()
            local action  = MetaShop.hit(vx, vy, shopState, profile and profile.rpBalance or 0)
            if action then
                if action.type == "start" then
                    commitShop()
                elseif action.type == "increment" then
                    if action.stype == "bonus" then
                        shopState.bonusSelections[action.id] = (shopState.bonusSelections[action.id] or 0) + 1
                    elseif action.stype == "deck" then
                        shopState.deckSelections[action.id] = (shopState.deckSelections[action.id] or 0) + 1
                    end
                elseif action.type == "decrement" then
                    if action.stype == "bonus" then
                        local cur = shopState.bonusSelections[action.id] or 0
                        if cur > 0 then shopState.bonusSelections[action.id] = cur - 1 end
                    elseif action.stype == "deck" then
                        local cur = shopState.deckSelections[action.id] or 0
                        if cur > 0 then shopState.deckSelections[action.id] = cur - 1 end
                    end
                elseif action.type == "toggle" then
                    local found = false
                    for i, mid in ipairs(shopState.challengeModIds) do
                        if mid == action.id then
                            table.remove(shopState.challengeModIds, i)
                            found = true; break
                        end
                    end
                    if not found then
                        shopState.challengeModIds[#shopState.challengeModIds + 1] = action.id
                    end
                end
            end
        end
        return
    end

    -- Game over screen
    if phase == "gameover" then
        if button == 1 then
            local action = GameOver.hit(vx, vy)
            if action == "play_again" then
                startGame(selectedRole)
            elseif action == "return_to_shop" then
                enterShop(selectedDifficulty)
            elseif action == "change_role" then
                phase = "setup"
            end
        end
        return
    end

    -- Modal absorbs all clicks
    if modal then
        local value = Modals.click(modal, vx, vy)
        if value == "cancel" then
            modal = nil; activeBtn = nil
        elseif value ~= nil then
            local cb = modal.onPick
            modal = nil
            cb(value)
        end
        return
    end

    if vy >= LAYOUT.mapY and vy < LAYOUT.mapY + LAYOUT.mapH then
        Map.mousepressed(vx, vy, button)
        if button == 1 then handleMapClick(vx, vy) end
        return
    end

    if button == 1 then
        local btnId = UIActions.hit(vx, vy, LAYOUT.actY, LAYOUT.actH, gs)
        if btnId then handleButtonClick(btnId); return end

        local cardIdx = Hand.hitCard(vx, vy, gs, LAYOUT.handY)
        if cardIdx then
            if selectedCard == cardIdx then
                local card = gs.hand[cardIdx]
                if phase == "action" and card.type == "event" then
                    handleCardPlay(card, cardIdx)
                else
                    selectedCard = nil
                end
            else
                selectedCard = cardIdx
            end
        end
    end
end

function love.mousemoved(sx, sy, dx, dy)
    local vx, vy = toVirtual(sx, sy)
    Tooltip.setMouse(vx, vy)
    -- Scale delta too
    local ww, wh = love.graphics.getDimensions()
    local scale  = math.min(ww/VIRTUAL_W, wh/VIRTUAL_H)
    Map.mousemoved(vx, vy, dx/scale, dy/scale)
end

function love.mousereleased(sx, sy, button)
    Map.mousereleased(button)
end

function love.wheelmoved(wx, wy)
    local sx, sy = love.mouse.getPosition()
    local vx, vy = toVirtual(sx, sy)
    Map.wheelmoved(vx, vy, wx, wy)
end

function love.keypressed(key)
    if key == "`" then
        Console.toggle()
        return
    end

    if Console.isOpen() then
        Console.keypressed(key)
        return
    end

    if key == "escape" then love.event.quit() end
    if key == "r" and phase == "gameover" then
        phase = "setup"
    end
end
