-- Enable Lua 5.3 compatibility layer (utf8, table.pack/unpack, string.pack/unpack)
require("compat53")
local utf8 = require("compat53.utf8")

local message = "Hello from ${TARGET_NAME} powered by LÖVE, Lua 5.3 Compat & Recudo! 🚀"

function love.load()
    love.window.setTitle("${TARGET_NAME}")
end

function love.draw()
    love.graphics.printf(message, 0, 260, love.graphics.getWidth(), "center")
    love.graphics.printf(
        string.format("UTF-8 Length: %d codepoints | table.pack test: %d items", utf8.len(message), table.pack("A", "B", "C").n),
        0, 300, love.graphics.getWidth(), "center"
    )
end
