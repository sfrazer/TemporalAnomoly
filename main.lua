local GameState  = require("src.state.gameState")
local Actions    = require("src.rules.actions")
local Phases     = require("src.rules.phases")
local WinLose    = require("src.rules.winLose")
local Mod        = require("src.state.modifiers")
local Roles      = require("src.rules.roles")

local Map        = require("src.ui.map")
local Hand       = require("src.ui.hand")
local UIActions  = require("src.ui.actions")
local Footer     = require("src.ui.footer")
local Modals     = require("src.ui.modals")
local RoleSelect = require("src.ui.roleSelect")

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
local gs          -- GameState table
local modal       -- active Modals.new() table, or nil
local activeBtn   -- currently highlighted action button id
local selectedCard  -- index into gs.hand, or nil
local message     -- {text, ttl} for brief feedback messages
local phase       -- "setup" | "action" | "draw" | "instability" | "gameover"
local gameResult  -- "won" | "lost" + reason

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
        phase      = "gameover"
        gameResult = {result = result, reason = reason}
    end
end

local function advancePhase()
    if phase == "action" then
        phase = "draw"
        Phases.runDrawPhase(gs)
        if gs.lost then endAction(); return end
        phase = "instability"
        Phases.runInstabilityPhase(gs)
        if gs.lost then endAction(); return end
        phase = "action"
        gs.actionsRemaining  = Mod.actionsPerTurn(gs)
        gs.coordinatorMoveUsed = false
        gs.turn = gs.turn + 1
    end
    endAction()
end

local function startGame(roleId)
    Mod.clear()
    gs = GameState.new({difficulty = "standard", role = roleId})
    gs.actionsRemaining = Mod.actionsPerTurn(gs)
    Roles.applyRole(gs, roleId)
    phase      = "action"
    modal      = nil
    activeBtn  = nil
    message    = nil
    gameResult = nil
    Map.setMapHeight(LAYOUT.mapH)
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

    if id == "end_turn" then
        advancePhase()
        return
    end

    if id == "build" then
        spendAction(function() return Actions.tryBuildOutpost(gs) end)
        return
    end

    if id == "clear" then
        modal = Modals.new("Clear which anomaly color?", COLOR_ITEMS, function(color)
            spendAction(function() return Actions.tryClear(gs, color) end)
        end)
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
-- Love2D callbacks
-- ---------------------------------------------------------------------------
function love.load()
    math.randomseed(os.time())
    phase = "setup"
    Map.setMapHeight(LAYOUT.mapH)
end

function love.update(dt)
    if message and message.ttl > 0 then
        message.ttl = message.ttl - dt
        if message.ttl <= 0 then message = nil end
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

    if phase == "setup" then
        RoleSelect.render()
        love.graphics.pop()
        return
    end

    Map.render(gs)
    UIActions.render(LAYOUT.actY, LAYOUT.actH, activeBtn, gs)
    Hand.render(gs, LAYOUT.handY, selectedCard)
    Footer.render(gs, LAYOUT.footerY, LAYOUT.footerH)

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
    if phase == "gameover" and gameResult then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)
        local won = gameResult.result == "won"
        love.graphics.setColor(won and 0.2 or 0.8, won and 0.8 or 0.2, 0.2)
        local title = won and "VICTORY" or "DEFEAT"
        love.graphics.printf(title, 0, 290, VIRTUAL_W, "center")
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf(gameResult.reason or "", 0, 340, VIRTUAL_W, "center")
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.printf("Press R to restart", 0, 380, VIRTUAL_W, "center")
    end

    -- Actions remaining indicator
    if phase == "action" then
        love.graphics.setColor(0.5, 0.6, 0.8, 0.7)
        love.graphics.printf("Actions: " .. tostring(gs.actionsRemaining), 0, LAYOUT.actY - 20, VIRTUAL_W, "right")
    end

    love.graphics.pop()
end

function love.mousepressed(sx, sy, button)
    local vx, vy = toVirtual(sx, sy)

    -- Role selection screen
    if phase == "setup" then
        if button == 1 then
            local roleId = RoleSelect.hit(vx, vy)
            if roleId then startGame(roleId) end
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
            selectedCard = (selectedCard == cardIdx) and nil or cardIdx
        end
    end
end

function love.mousemoved(sx, sy, dx, dy)
    local vx, vy = toVirtual(sx, sy)
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
    if key == "escape" then love.event.quit() end
    if key == "r" and phase == "gameover" then
        phase = "setup"
        gs    = nil
    end
end
