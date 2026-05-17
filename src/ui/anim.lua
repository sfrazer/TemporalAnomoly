-- Lightweight animation queue.
-- Trigger functions are called by main.lua event handlers; render() is drawn
-- above the game UI but below the debug console each frame.
--
-- Phase banners accept an optional `delay` (seconds) so "Draw Phase" and
-- "Instability Phase" can be queued in the same frame and still play
-- sequentially. Animations with t < 0 are still in their delay period.

local M = {}

local VW, VH = 1280, 720

local _anims = {}

-- Screen-shake: amp decays to zero over shakeDur seconds.
local _shakeAmp = 0
local _shakeDur = 0

local CUBE_COLOR = {
    blue   = {0.20, 0.45, 0.92},
    yellow = {0.92, 0.82, 0.05},
    black  = {0.65, 0.65, 0.70},
    red    = {0.90, 0.15, 0.15},
}

-- ---------------------------------------------------------------------------
-- Trigger functions (called from main.lua; never from rules modules)
-- ---------------------------------------------------------------------------

-- Brief expanding ring in the cube's color at virtual position (vx, vy).
function M.cubePlaced(vx, vy, color)
    _anims[#_anims + 1] = {
        type = "cube_flash", vx = vx, vy = vy, color = color,
        t = 0, duration = 0.38,
    }
end

-- Two expanding rings + screen shake at virtual position (vx, vy).
function M.explosion(vx, vy)
    _anims[#_anims + 1] = {
        type = "explosion", vx = vx, vy = vy,
        t = 0, duration = 0.80,
    }
    _shakeAmp = 5
    _shakeDur = 0.32
end

-- Orange screen-edge pulse (Chronological Flux).
function M.fluxPulse()
    _anims[#_anims + 1] = {
        type = "flux_pulse",
        t = 0, duration = 0.55,
    }
end

-- Centered phase name banner. delay (seconds) lets back-to-back banners
-- play sequentially even when queued in the same frame.
-- Caps at 2 queued banners to prevent runaway stacking.
function M.phaseBanner(text, delay)
    local count = 0
    for _, a in ipairs(_anims) do
        if a.type == "phase_banner" then count = count + 1 end
    end
    if count >= 2 then return end
    _anims[#_anims + 1] = {
        type = "phase_banner", text = text,
        t = -(delay or 0), duration = 1.40,
    }
end

-- ---------------------------------------------------------------------------
-- Shake
-- ---------------------------------------------------------------------------

-- Returns a small random (dx, dy) offset while shake is active.
function M.getShakeOffset()
    if _shakeDur <= 0 then return 0, 0 end
    local amp = _shakeAmp * (_shakeDur / 0.32)  -- taper off
    return (math.random() * 2 - 1) * amp,
           (math.random() * 2 - 1) * amp * 0.45
end

-- ---------------------------------------------------------------------------
-- Update / render
-- ---------------------------------------------------------------------------

function M.update(dt)
    _shakeDur = math.max(0, _shakeDur - dt)
    if _shakeDur <= 0 then _shakeAmp = 0 end

    local i = 1
    while i <= #_anims do
        _anims[i].t = _anims[i].t + dt
        if _anims[i].t >= _anims[i].duration then
            table.remove(_anims, i)
        else
            i = i + 1
        end
    end
end

local BANNER_Y    = 298   -- top of banner strip
local BANNER_H    = 52
local BANNER_FADE = 0.28  -- seconds for fade in / fade out

function M.render()
    for _, a in ipairs(_anims) do
        if a.t < 0 then goto continue end   -- still in delay

        local p = a.t / a.duration   -- 0..1 progress

        if a.type == "cube_flash" then
            local cc = CUBE_COLOR[a.color] or {1, 1, 1}
            love.graphics.setColor(cc[1], cc[2], cc[3], (1 - p) * 0.70)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", a.vx, a.vy, 20 + p * 16)

        elseif a.type == "explosion" then
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(0.95, 0.50, 0.10, (1 - p) * 0.85)
            love.graphics.circle("line", a.vx, a.vy, 20 + p * 58)
            love.graphics.setColor(1.00, 0.82, 0.20, (1 - p) * 0.55)
            love.graphics.circle("line", a.vx, a.vy, 20 + p * 32)

        elseif a.type == "flux_pulse" then
            local alpha = (1 - p) * 0.62
            love.graphics.setColor(0.95, 0.55, 0.12, alpha)
            local ew = 30
            love.graphics.rectangle("fill", 0,      0,       VW, ew)
            love.graphics.rectangle("fill", 0,      VH - ew, VW, ew)
            love.graphics.rectangle("fill", 0,      0,       ew, VH)
            love.graphics.rectangle("fill", VW - ew, 0,      ew, VH)

        elseif a.type == "phase_banner" then
            local alpha
            if a.t < BANNER_FADE then
                alpha = a.t / BANNER_FADE
            elseif a.t > a.duration - BANNER_FADE then
                alpha = (a.duration - a.t) / BANNER_FADE
            else
                alpha = 1.0
            end
            alpha = math.max(0, math.min(1, alpha))

            love.graphics.setColor(0.04, 0.05, 0.09, alpha * 0.90)
            love.graphics.rectangle("fill", 0, BANNER_Y, VW, BANNER_H)
            love.graphics.setColor(0.28, 0.32, 0.52, alpha * 0.65)
            love.graphics.setLineWidth(1)
            love.graphics.line(0, BANNER_Y,            VW, BANNER_Y)
            love.graphics.line(0, BANNER_Y + BANNER_H, VW, BANNER_Y + BANNER_H)
            love.graphics.setColor(0.76, 0.84, 0.96, alpha)
            love.graphics.printf(a.text, 0, BANNER_Y + 17, VW, "center")
        end

        ::continue::
    end
end

return M
