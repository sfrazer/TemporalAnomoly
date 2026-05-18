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
local MainMenu         = require("src.ui.mainMenu")
local Options          = require("src.ui.options")

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
local phase             -- "profileselect"|"mainmenu"|"options"|"setup"|"difficulty"|"shop"|"action"|"gameover"|"instability_anim"
local gameResult        -- {result, reason, earnedRP, newUnlocks}
local profilesCache     -- [slot] = profile_table_or_nil, used by profileselect
local selectedRole      -- role id chosen on role-select screen, held until shop commits
local selectedDifficulty -- difficulty id chosen before shop, held until commitShop
local shopState         -- pending shop selections {bonusSelections, deckSelections, challengeModIds}
local initAnims         -- forward declaration; defined below action handlers
local handleCardPlay    -- forward declaration; defined alongside initAnims
local finishInstability -- forward declaration; called by update drain loop

-- Profile naming overlay (shown when creating a new profile on profileselect screen)
local namingState       -- {slot=n, text=""} or nil

-- Options confirm overlay: "quit_run"|"exit_game" or nil
local optionsConfirm
-- Phase to restore when options "Back" is clicked (nil → go to mainmenu)
local optionsPrevPhase

-- Instability animation state (drained one step per instabilityDelay seconds)
local instabilitySteps = {}
local instabilityIdx   = 1
local instabilityTimer = 0
local instabilityDelay = 5.0

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

local function titleCase(s)
    return s:gsub("_", " "):gsub("(%a)([%a]*)", function(a, b) return a:upper() .. b end)
end

local function executeInstabilityStep(step)
    if gs.lost then return end
    local card = step.card
    if step.stepType == "challengemod" then
        Phases.applyChallengeModEffect(gs, card)
        Anim.threatReveal("Challenge Mod: " .. (card.name or card.id), nil)
    else
        Mod.onThreatCardDraw(gs, {card = card})
        if not gs.repaired[card.color] then
            local cubes = Mod.cubesPerThreatCard(gs)
            Explosion.placeCubesAt(gs, card.city, card.period, card.color, cubes)
        end
        Anim.threatReveal(titleCase(card.city) .. " / " .. titleCase(card.period), card.color)
    end
end

finishInstability = function()
    gs.sealedCity = nil
    if gs.lost then endAction(); return end
    phase = "action"
    gs.actionsRemaining    = Mod.actionsPerTurn(gs)
    gs.coordinatorMoveUsed = false
    if (gs.teleportBannedTurns or 0) > 0 then
        gs.teleportBannedTurns = gs.teleportBannedTurns - 1
    end
    gs.turn = gs.turn + 1
    endAction()
end

local function advancePhase()
    if phase == "action" then
        Anim.phaseBanner("Draw Phase", 0)
        phase = "draw"
        Phases.runDrawPhase(gs)
        if gs.lost then endAction(); return end
        Anim.phaseBanner("Instability Phase", 0.70)

        local profile = AutoSave.getProfile()
        instabilityDelay = (profile and profile.instabilityStepDelay) or 5.0
        local steps = Phases.buildInstabilitySteps(gs)

        if #steps == 0 then
            -- Skipped (Paradox Barrier) or empty deck edge case
            finishInstability()
            return
        end

        -- Enter async drain: cubes placed one card at a time with instabilityDelay gaps.
        phase            = "instability_anim"
        instabilitySteps = steps
        instabilityIdx   = 1
        instabilityTimer = 0
        -- Clear UI immediately; save deferred until finishInstability()
        activeBtn    = nil
        selectedCard = nil
        modal        = nil
        -- Execute first card right away so the player sees something immediately
        executeInstabilityStep(steps[1])
        instabilityIdx = 2
    end
end

local function enterProfileSelect()
    profilesCache = {}
    for slot = 1, Save.SLOT_COUNT do
        profilesCache[slot] = Save.loadProfile(slot)
    end
    phase         = "profileselect"
    gs            = nil
    modal         = nil
    activeBtn     = nil
    message       = nil
    gameResult    = nil
    namingState   = nil
    optionsConfirm = nil
end

local function resumeGame(runData, slot, profile)
    Mod.clear()
    initAnims()
    gs = runData
    Roles.applyRole(gs, gs.role)
    RunPrep.applyModifiers(RunPrep.prepOpts(profile or Save.newProfile(), gs.role))
    AutoSave.init(slot, profile)
    Hand.setSortMode(profile and profile.handSortMode or "insertion")
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
    Hand.setSortMode(profile and profile.handSortMode or "insertion")
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

local function enterMainMenu()
    phase           = "mainmenu"
    modal           = nil
    activeBtn       = nil
    message         = nil
    gameResult      = nil
    optionsConfirm  = nil
    optionsPrevPhase = nil
end

local function enterOptions(fromPhase)
    optionsPrevPhase = fromPhase
    optionsConfirm   = nil
    phase            = "options"
end

local function leaveOptions()
    if optionsPrevPhase and optionsPrevPhase ~= "mainmenu" then
        phase            = optionsPrevPhase
        optionsPrevPhase = nil
        optionsConfirm   = nil
    else
        enterMainMenu()
    end
end

local function confirmProfileName()
    local slot = namingState.slot
    local name = namingState.text
    namingState  = nil
    local profile = Save.newProfile()
    profile.name  = name
    Save.saveProfile(slot, profile)
    Save.saveIndex({lastUsed = slot})
    profilesCache[slot] = profile
    AutoSave.init(slot, profile)
    enterMainMenu()
end

local function selectProfile(slot)
    local profile = profilesCache[slot]
    if not profile then
        namingState = {slot = slot, text = ""}
        return
    end
    Save.saveIndex({lastUsed = slot})
    AutoSave.init(slot, profile)
    if profile.activeRun then
        resumeGame(profile.activeRun, slot, profile)
    else
        enterMainMenu()
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
        -- Phase does NOT auto-advance at 0 actions; player must click End Turn.
        -- This lets event cards be played after the last action is spent.
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

    -- Guard action-costing buttons when out of actions.
    local costsAction = (id == "build" or id == "clear" or id == "resolve" or id == "peek_threat")
    if costsAction and gs.actionsRemaining <= 0 then
        showMsg("No actions remaining — click End Turn")
        activeBtn = nil
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
        if not gs.outposts[gs.currentCity] then
            showMsg("Must be at a Temporal Outpost to Resolve")
            activeBtn = nil
            return
        end
        local threshold = Mod.cardsToResolveAnomaly(gs)
        local colorCounts = {}
        for _, c in ipairs(gs.hand) do
            if c.type == "city" then
                colorCounts[c.color] = (colorCounts[c.color] or 0) + 1
            end
        end
        local items = {}
        for _, item in ipairs(COLOR_ITEMS) do
            local count    = colorCounts[item.value] or 0
            local resolved = gs.resolved[item.value]
            items[#items+1] = {
                label    = item.label .. " — " .. count .. "/" .. threshold .. " cards" ..
                           (resolved and " [RESOLVED]" or ""),
                value    = item.value,
                disabled = resolved or count < threshold,
                tip      = resolved
                    and "This anomaly is already RESOLVED."
                    or  (count >= threshold
                        and count .. " matching cards — ready to RESOLVE"
                        or  "Need " .. threshold .. " cards (" .. count .. " in hand)"),
            }
        end
        modal = Modals.new("Resolve which anomaly?", items, function(color)
            spendAction(function() return Actions.tryResolve(gs, color) end)
        end)
        return
    end

    if id == "coordinator_move" then
        showMsg("Click a city with a Temporal Outpost to move there for free")
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

    if id == "reorder_threat" then
        local REORDER_MAX = 6
        local n = math.min(REORDER_MAX, #gs.threatDeck)
        if n == 0 then showMsg("Threat deck is empty"); activeBtn = nil; return end
        local items = {}
        for i = 1, n do
            local card = gs.threatDeck[i]
            local label = card.city
                and (titleCase(card.city) .. " / " .. titleCase(card.period))
                or  (card.name or card.id)
            items[#items + 1] = {label = label, value = card}
        end
        modal = Modals.newReorder("Reorder Top " .. n .. " Threat Cards:", items, function(ordered)
            local cards = {}
            for _, item in ipairs(ordered) do cards[#cards + 1] = item.value end
            local ok, err = Actions.tryReorderThreats(gs, cards)
            if ok then showMsg("Threat deck reordered"); endAction()
            else       showMsg(err or "Cannot reorder") end
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
    if phase ~= "action" then return end
    local hit = Map.hitCity(vx, vy)
    if not hit then return end

    -- Coordinator button flow: button sets activeBtn, then player clicks destination.
    if activeBtn == "coordinator_move" then
        local ok, err = Actions.tryCoordinatorMove(gs, hit.city)
        if ok then endAction() else showMsg(err or "Cannot move there"); activeBtn = nil end
        return
    end

    -- Unified click-to-move: determine every legal way to reach this node.
    local destCity, destPeriod = hit.city, hit.period

    -- Coordinator free move available to this destination?
    local coordAvail = gs.role == "coordinator"
        and not gs.coordinatorMoveUsed
        and gs.outposts[destCity]
        and destCity ~= gs.currentCity

    -- Standard movement options (only if actions remain).
    local moveOpts = gs.actionsRemaining > 0
        and Actions.movementOptions(gs, destCity, destPeriod)
        or {}

    -- Build the items list shown in the picker modal.
    local items = {}
    if coordAvail then
        items[#items+1] = {label = "Coordinator Move (free)", value = "coordinator_move"}
    end
    for _, o in ipairs(moveOpts) do
        if o == "travel" then
            items[#items+1] = {label = "Travel (1 action)", value = "travel"}
        elseif o == "teleport" then
            items[#items+1] = {
                label = "Teleport — discard " .. destCity .. "/" .. destPeriod .. " (1 action)",
                value = "teleport",
            }
        elseif o == "teleport_alt" then
            items[#items+1] = {
                label = "Teleport Alt — discard " .. gs.currentCity .. "/" .. gs.currentPeriod .. " (1 action)",
                value = "teleport_alt",
            }
        end
    end

    if #items == 0 then
        if gs.actionsRemaining <= 0 and not coordAvail then
            showMsg("No actions left")
        else
            showMsg("No valid move to " .. destCity .. " / " .. destPeriod)
        end
        return
    end

    local function execute(choice)
        if choice == "travel" then
            spendAction(function() return Actions.tryTravel(gs, destCity, destPeriod) end)
        elseif choice == "teleport" then
            spendAction(function() return Actions.tryTeleport(gs, destCity, destPeriod) end)
        elseif choice == "teleport_alt" then
            spendAction(function() return Actions.tryTeleportAlt(gs, destCity, destPeriod) end)
        elseif choice == "coordinator_move" then
            local ok, err = Actions.tryCoordinatorMove(gs, destCity)
            if ok then endAction() else showMsg(err or "Cannot move there") end
        end
    end

    -- Travel is unambiguous — execute immediately without a modal.
    for _, o in ipairs(moveOpts) do
        if o == "travel" then execute("travel"); return end
    end

    if #items == 1 then
        execute(items[1].value)
    else
        modal = Modals.new("Move to " .. destCity .. "?", items, execute)
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

    local index = Save.loadIndex()
    if index.lastUsed then
        local profile = Save.loadProfile(index.lastUsed)
        if profile then
            AutoSave.init(index.lastUsed, profile)
            enterMainMenu()
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

    if phase == "instability_anim" then
        -- Finish immediately on loss so gameover shows without waiting
        if gs and gs.lost then
            finishInstability()
            return
        end
        instabilityTimer = instabilityTimer + dt
        if instabilityTimer >= instabilityDelay then
            instabilityTimer = instabilityTimer - instabilityDelay
            if instabilityIdx <= #instabilitySteps then
                executeInstabilityStep(instabilitySteps[instabilityIdx])
                instabilityIdx = instabilityIdx + 1
            else
                finishInstability()
            end
        end
    end
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
        -- Naming overlay
        if namingState then
            love.graphics.setColor(0, 0, 0, 0.65)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)
            local bw, bh = 480, 180
            local bx, by = (1280 - bw) / 2, (720 - bh) / 2
            love.graphics.setColor(0.10, 0.12, 0.16)
            love.graphics.rectangle("fill", bx, by, bw, bh, 8)
            love.graphics.setColor(0.35, 0.40, 0.52)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", bx, by, bw, bh, 8)
            love.graphics.setColor(0.80, 0.83, 0.95)
            love.graphics.printf("Name your profile:", bx, by + 22, bw, "center")
            -- Text field
            local tfx, tfy, tfw, tfh = bx + 32, by + 60, bw - 64, 40
            love.graphics.setColor(0.06, 0.07, 0.10)
            love.graphics.rectangle("fill", tfx, tfy, tfw, tfh, 4)
            love.graphics.setColor(0.45, 0.50, 0.65)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", tfx, tfy, tfw, tfh, 4)
            local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "|" or ""
            love.graphics.setColor(0.90, 0.92, 0.98)
            local font = love.graphics.getFont()
            love.graphics.print(namingState.text .. cursor, tfx + 10, tfy + (tfh - font:getHeight()) / 2)
            -- Buttons
            local btnW, btnH = 100, 36
            -- Create
            love.graphics.setColor(0.18, 0.42, 0.20)
            love.graphics.rectangle("fill", bx + bw/2 - btnW - 10, by + bh - btnH - 18, btnW, btnH, 4)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf("Create", bx + bw/2 - btnW - 10, by + bh - btnH - 18 + (btnH - font:getHeight())/2, btnW, "center")
            -- Cancel
            love.graphics.setColor(0.40, 0.18, 0.18)
            love.graphics.rectangle("fill", bx + bw/2 + 10, by + bh - btnH - 18, btnW, btnH, 4)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf("Cancel", bx + bw/2 + 10, by + bh - btnH - 18 + (btnH - font:getHeight())/2, btnW, "center")
        end
        love.graphics.pop()
        return
    end

    if phase == "mainmenu" then
        MainMenu.render(AutoSave.getProfile())
        love.graphics.pop()
        return
    end

    if phase == "options" then
        local profile = AutoSave.getProfile()
        local inRun   = profile and profile.activeRun ~= nil
        Options.render(profile, inRun)
        -- Confirm overlay
        if optionsConfirm then
            love.graphics.setColor(0, 0, 0, 0.65)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)
            local bw, bh = 440, 140
            local bx, by = (1280 - bw) / 2, (720 - bh) / 2
            love.graphics.setColor(0.10, 0.12, 0.16)
            love.graphics.rectangle("fill", bx, by, bw, bh, 8)
            love.graphics.setColor(0.42, 0.22, 0.22)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", bx, by, bw, bh, 8)
            local msg = optionsConfirm == "quit_run" and "Abandon the active run?" or "Exit the game?"
            love.graphics.setColor(0.88, 0.90, 0.95)
            love.graphics.printf(msg, bx, by + 22, bw, "center")
            local font = love.graphics.getFont()
            local btnW, btnH = 100, 36
            -- Yes
            love.graphics.setColor(0.42, 0.18, 0.18)
            love.graphics.rectangle("fill", bx + bw/2 - btnW - 10, by + bh - btnH - 18, btnW, btnH, 4)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf("Yes", bx + bw/2 - btnW - 10, by + bh - btnH - 18 + (btnH - font:getHeight())/2, btnW, "center")
            -- No
            love.graphics.setColor(0.18, 0.42, 0.20)
            love.graphics.rectangle("fill", bx + bw/2 + 10, by + bh - btnH - 18, btnW, btnH, 4)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf("No", bx + bw/2 + 10, by + bh - btnH - 18 + (btnH - font:getHeight())/2, btnW, "center")
        end
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
        love.graphics.printf("Actions: " .. tostring(gs.actionsRemaining), 0, LAYOUT.actY - 20, VIRTUAL_W - 48, "right")
    end

    -- Options button (visible during active game phases)
    if phase == "action" or phase == "gameover" then
        love.graphics.setColor(0.16, 0.18, 0.24, 0.85)
        love.graphics.rectangle("fill", 1242, 4, 34, 26, 4)
        love.graphics.setColor(0.40, 0.44, 0.56)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 1242, 4, 34, 26, 4)
        love.graphics.setColor(0.72, 0.76, 0.88)
        local font = love.graphics.getFont()
        love.graphics.printf("=", 1242, 4 + (26 - font:getHeight()) / 2, 34, "center")
    end

    Anim.render()
    if modal then Tooltip.suppress() end
    Tooltip.render()
    Console.render()

    love.graphics.pop()
end

function love.textinput(text)
    if namingState then
        if #namingState.text < 16 then
            namingState.text = namingState.text .. text
        end
        return
    end
    Console.textinput(text)
end

function love.mousepressed(sx, sy, button)
    local vx, vy = toVirtual(sx, sy)

    -- Profile selection screen
    if phase == "profileselect" then
        if button == 1 then
            -- Naming overlay intercepts all clicks
            if namingState then
                local bw, bh = 480, 180
                local bx, by = (1280 - bw) / 2, (720 - bh) / 2
                local btnW, btnH = 100, 36
                local btnY2 = by + bh - btnH - 18
                -- Create button
                if vx >= bx + bw/2 - btnW - 10 and vx <= bx + bw/2 - 10 and
                   vy >= btnY2 and vy <= btnY2 + btnH then
                    confirmProfileName()
                end
                -- Cancel button
                if vx >= bx + bw/2 + 10 and vx <= bx + bw/2 + btnW + 10 and
                   vy >= btnY2 and vy <= btnY2 + btnH then
                    namingState = nil
                end
                return
            end
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

    -- Main menu screen
    if phase == "mainmenu" then
        if button == 1 then
            local profile = AutoSave.getProfile()
            local action  = MainMenu.hit(vx, vy, profile)
            if action == "resume" then
                resumeGame(profile.activeRun, AutoSave.getSlot(), profile)
            elseif action == "new_run" then
                phase = "setup"
            elseif action == "change_profile" then
                enterProfileSelect()
            elseif action == "options" then
                enterOptions("mainmenu")
            end
        end
        return
    end

    -- Options screen
    if phase == "options" then
        if button == 1 then
            local profile = AutoSave.getProfile()
            local inRun   = gs ~= nil or (profile and profile.activeRun ~= nil)
            -- Confirm overlay intercepts clicks
            if optionsConfirm then
                local bw, bh = 440, 140
                local bx, by = (1280 - bw) / 2, (720 - bh) / 2
                local btnW, btnH = 100, 36
                local btnY2 = by + bh - btnH - 18
                if vx >= bx + bw/2 - btnW - 10 and vx <= bx + bw/2 - 10 and
                   vy >= btnY2 and vy <= btnY2 + btnH then
                    -- Yes
                    if optionsConfirm == "quit_run" then
                        gs = nil
                        local slot = AutoSave.getSlot()
                        profile.activeRun = nil
                        Save.saveProfile(slot, profile)
                        AutoSave.init(slot, profile)
                        optionsConfirm = nil
                        enterMainMenu()
                    elseif optionsConfirm == "exit_game" then
                        love.event.quit()
                    end
                elseif vx >= bx + bw/2 + 10 and vx <= bx + bw/2 + btnW + 10 and
                       vy >= btnY2 and vy <= btnY2 + btnH then
                    -- No
                    optionsConfirm = nil
                end
                return
            end
            local action = Options.hit(vx, vy, profile, inRun)
            if action == "back" then
                leaveOptions()
            elseif action == "exit_game" then
                optionsConfirm = "exit_game"
            elseif action == "quit_run" then
                optionsConfirm = "quit_run"
            elseif action == "delay_dec" then
                profile.instabilityStepDelay = math.max(0.5, (profile.instabilityStepDelay or 5.0) - 0.5)
                Save.saveProfile(AutoSave.getSlot(), profile)
            elseif action == "delay_inc" then
                profile.instabilityStepDelay = math.min(10.0, (profile.instabilityStepDelay or 5.0) + 0.5)
                Save.saveProfile(AutoSave.getSlot(), profile)
            elseif action == "fullscreen_toggle" then
                profile.fullscreen = not (profile.fullscreen or false)
                Save.saveProfile(AutoSave.getSlot(), profile)
                love.window.setFullscreen(profile.fullscreen)
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

    -- Options button (top-right corner, visible during action/gameover)
    if button == 1 and (phase == "action" or phase == "gameover") then
        if vx >= 1242 and vx <= 1276 and vy >= 4 and vy <= 30 then
            enterOptions(phase)
            return
        end
    end

    -- Modal absorbs all clicks
    if modal then
        local value = Modals.click(modal, vx, vy)
        if value == "cancel" then
            modal = nil; activeBtn = nil
        elseif value == "reorder" then
            -- arrow hit: modal.items already mutated; keep modal open
        elseif value ~= nil then
            local cb = modal.onPick
            modal = nil
            cb(value)
        end
        return
    end

    if vy >= LAYOUT.mapY and vy < LAYOUT.mapY + LAYOUT.mapH then
        if button == 1 then handleMapClick(vx, vy) end
        return
    end

    if button == 1 then
        local btnId = UIActions.hit(vx, vy, LAYOUT.actY, LAYOUT.actH, gs)
        if btnId then handleButtonClick(btnId); return end

        local ctrl = gs and Hand.hitControl(vx, vy, LAYOUT.handY, #gs.hand) or nil
        if ctrl == "scroll_left" then
            Hand.scrollLeft()
        elseif ctrl == "scroll_right" then
            Hand.scrollRight(#gs.hand)
        elseif ctrl == "sort" then
            local newMode = Hand.cycleSortMode()
            local profile = AutoSave.getProfile()
            if profile then
                profile.handSortMode = newMode
                Save.saveProfile(AutoSave.getSlot(), profile)
            end
        else
            local cardIdx = gs and Hand.hitCard(vx, vy, gs, LAYOUT.handY) or nil
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
end

function love.mousemoved(sx, sy)
    local vx, vy = toVirtual(sx, sy)
    Tooltip.setMouse(vx, vy)
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

    -- Profile naming overlay
    if namingState then
        if key == "backspace" then
            namingState.text = namingState.text:sub(1, -2)
        elseif key == "return" or key == "kpenter" then
            confirmProfileName()
        elseif key == "escape" then
            namingState = nil
        end
        return
    end

    if key == "escape" then
        if phase == "options" then
            if optionsConfirm then
                optionsConfirm = nil
            else
                leaveOptions()
            end
        elseif phase == "action" or phase == "gameover" then
            enterOptions(phase)
        end
        -- mainmenu, profileselect, setup, difficulty, shop: no escape action
    end
    if key == "r" and phase == "gameover" then
        phase = "setup"
    end
end
