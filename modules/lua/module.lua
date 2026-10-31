-- Lua modules as xmake packages.
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- import("lua.module") is the public surface. Names, the installed tree and
-- the recipe builder live in the sibling modules.

local modules_root = path.directory(os.scriptdir())
import("lua.recipe", {rootdir = modules_root, inherit = true})
