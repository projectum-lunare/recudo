local am = require("amulet")

function am.init()
    local win = am.window{title = "${TARGET_NAME}"}
    local text = am.text("Hello from ${TARGET_NAME} powered by Amulet & Forge!")
    win.scene = text
end
