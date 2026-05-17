-- Named audio hook points. Every function is a no-op when the corresponding
-- asset file is absent, so callers never need to guard against missing audio.
--
-- Drop a .ogg file into assets/audio/ matching the name below and it will
-- be picked up automatically on next launch — no code changes needed.
--
-- cubePlaced fires many times per turn, so it only plays when the previous
-- instance has finished to avoid rapid-fire chopping.

local M = {}

local FILES = {
    cubePlaced  = "assets/audio/cube_placed.ogg",
    explosion   = "assets/audio/explosion.ogg",
    flux        = "assets/audio/flux.ogg",
    win         = "assets/audio/win.ogg",
    lose        = "assets/audio/lose.ogg",
    buttonClick = "assets/audio/click_003.ogg",
}

local sources = {}

for name, path in pairs(FILES) do
    if love.filesystem.getInfo(path) then
        local ok, src = pcall(love.audio.newSource, path, "static")
        if ok then sources[name] = src end
    end
end

-- Play a sound by name, restarting it if already playing.
local function play(name)
    local src = sources[name]
    if not src then return end
    src:stop()
    src:play()
end

-- Play only if the previous instance has finished (avoids rapid-fire chopping).
local function playIfDone(name)
    local src = sources[name]
    if not src then return end
    if not src:isPlaying() then src:play() end
end

function M.cubePlaced()  playIfDone("cubePlaced")  end
function M.explosion()   play("explosion")          end
function M.flux()        play("flux")               end
function M.win()         play("win")                end
function M.lose()        play("lose")               end
function M.buttonClick() play("buttonClick")        end

return M
