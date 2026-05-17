-- Debug console. Toggle with backtick. Only active during gameplay.
-- Commands are registered from main.lua so closures can capture game state.

local M = {}

local VW      = 1280
local VH      = 720
local LINE_H  = 16
local PAD     = 8
local VISIBLE = 12   -- output lines shown at once
local PANEL_H = VISIBLE * LINE_H + LINE_H + PAD * 3

local open     = false
local history  = {}
local scroll   = 0   -- lines scrolled up from the bottom (up/down arrow keys)
local inputBuf = ""
local cursorOn = true
local cursorT  = 0

local commands = {}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function M.isOpen() return open end

function M.toggle()
    open    = not open
    cursorT = 0
    cursorOn = true
end

-- Register a named command. fn receives the split args table; return a string
-- to print, or nil for no output. Multi-line: call M.print() inside fn.
function M.register(name, fn)
    commands[name:lower()] = fn
end

function M.update(dt)
    if not open then return end
    cursorT = cursorT + dt
    if cursorT >= 0.5 then
        cursorOn = not cursorOn
        cursorT  = 0
    end
end

local function addLine(text)
    history[#history + 1] = tostring(text)
end

-- Multi-line output helper callable from within command handlers.
function M.print(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    addLine(table.concat(parts, "  "))
end

function M.execute(line)
    line = line:match("^%s*(.-)%s*$")
    if line == "" then return end
    addLine("> " .. line)
    scroll = 0  -- jump to bottom on new command

    local parts = {}
    for word in line:gmatch("%S+") do parts[#parts + 1] = word end
    local cmd = parts[1] and parts[1]:lower()
    local fn  = commands[cmd]
    if fn then
        local ok, result = pcall(fn, parts)
        if ok then
            if result ~= nil then addLine(tostring(result)) end
        else
            addLine("Error: " .. tostring(result))
        end
    else
        addLine("Unknown command: " .. (cmd or "(empty)") .. "  (type 'help')")
    end
end

function M.textinput(text)
    if not open then return end
    if text == "`" then return end  -- backtick toggles; don't add it to input
    inputBuf = inputBuf .. text
end

function M.keypressed(key)
    if not open then return end
    if key == "return" or key == "kpenter" then
        M.execute(inputBuf)
        inputBuf = ""
    elseif key == "backspace" then
        inputBuf = inputBuf:sub(1, -2)
    elseif key == "up" then
        local maxScroll = math.max(0, #history - VISIBLE)
        scroll = math.min(scroll + 1, maxScroll)
    elseif key == "down" then
        scroll = math.max(0, scroll - 1)
    end
end

function M.render()
    if not open then return end

    local panelY = VH - PANEL_H

    -- Background panel
    love.graphics.setColor(0.03, 0.04, 0.06, 0.93)
    love.graphics.rectangle("fill", 0, panelY, VW, PANEL_H)
    love.graphics.setColor(0.25, 0.30, 0.45)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, panelY, VW, panelY)

    -- Output lines
    local total    = #history
    local maxScroll = math.max(0, total - VISIBLE)
    scroll = math.min(scroll, maxScroll)
    local startIdx = math.max(1, total - VISIBLE + 1 - scroll)
    local endIdx   = math.max(0, total - scroll)

    for i = startIdx, endIdx do
        local row  = i - startIdx
        local text = history[i]
        if text:sub(1, 2) == "> " then
            love.graphics.setColor(0.42, 0.46, 0.60)  -- dim for echoed commands
        else
            love.graphics.setColor(0.72, 0.82, 0.68)  -- green-ish for output
        end
        love.graphics.print(text, PAD, panelY + PAD + row * LINE_H)
    end

    -- Scroll indicator
    if scroll > 0 then
        love.graphics.setColor(0.38, 0.42, 0.55)
        love.graphics.print("↑ " .. scroll .. " lines", VW - 80, panelY + PAD)
    end

    -- Input separator
    local inputY = panelY + PANEL_H - LINE_H - PAD
    love.graphics.setColor(0.18, 0.22, 0.32)
    love.graphics.rectangle("fill", 0, inputY - 3, VW, 1)

    -- Prompt + buffer + cursor
    love.graphics.setColor(0.30, 0.88, 0.45)
    love.graphics.print("> " .. inputBuf .. (cursorOn and "█" or " "), PAD, inputY)
end

return M
