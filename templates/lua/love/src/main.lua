function love.load()
    love.window.setTitle("${TARGET_NAME}")
end

function love.draw()
    love.graphics.printf("Hello from ${TARGET_NAME} powered by LÖVE & Forge!", 0, 280, love.graphics.getWidth(), "center")
end
