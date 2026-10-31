-- Projectum Lunare Forge - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- Each rule lives in its own file. xmake only auto-includes rules/**/xmake.lua.
local here = os.scriptdir()
includes(path.join(here, "module.lua"))
includes(path.join(here, "bin.lua"))
includes(path.join(here, "app.lua"))
includes(path.join(here, "bundle.lua"))
