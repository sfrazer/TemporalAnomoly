function love.load()
    print("Temporal Anomaly — Phase 0")
end

function love.update(dt)
end

function love.draw()
    love.graphics.print("Temporal Anomaly — Phase 0", 10, 10)
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end
