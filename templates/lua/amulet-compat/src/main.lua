-- Enable Lua 5.3 compatibility layer (utf8, table.pack/unpack, string.pack/unpack)
require("compat53")
local utf8 = require("compat53.utf8")
local am = require("amulet")

function am.init()
    local win = am.window{title = "${TARGET_NAME}"}
    local greeting = "Hello from ${TARGET_NAME} powered by Amulet, Lua 5.3 Compat & Forge! 🎮"
    local text = am.text(string.format(
        "%s\n(UTF-8 codepoints: %d | table.pack: %d items)",
        greeting,
        utf8.len(greeting),
        table.pack(1, 2, 3).n
    ))
    win.scene = text
end
