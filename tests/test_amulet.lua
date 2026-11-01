-- Unit Tests: Amulet Game Toolkit Rule (forge.amulet)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

import("modules.template", {rootdir = os.projectdir()})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "amulet rule files exist and define expected rule names",
        func = function ()
            local content_xmake = io.readfile("rules/engine/amulet/xmake.lua")
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find("game.lua") ~= nil)

            local content_game = io.readfile("rules/engine/amulet/game.lua")
            T.assert_not_nil(content_game)
            T.assert_true(content_game:find('setup_amulet_rule%("forge%.engine%.amulet"%)') ~= nil)
            T.assert_true(content_game:find('setup_amulet_rule%("forge%.amulet"%)') ~= nil)
            T.assert_true(content_game:find('setup_amulet_rule%("forge%.amulet%.game"%)') ~= nil)
            T.assert_true(content_game:find('setup_amulet_rule%("forge%.lua%.amulet"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "amulet launcher template preloads native C modules and hooks engine",
        func = function ()
            local content_game = io.readfile("rules/engine/amulet/game.lua")
            local template_str = content_game:match("local LAUNCHER_TEMPLATE = %[%[\n(.-)%]\n%]\n\nlocal function find_game_dir")
            if not template_str then
                template_str = content_game:match("local LAUNCHER_TEMPLATE = %[%[\n(.-)\n%]%]")
            end
            T.assert_not_nil(template_str, "LAUNCHER_TEMPLATE not found in game.lua")

            local render = template.compile(template_str)
            local code = render({
                native_modules = {
                    {name = "cjson", symbol = "luaopen_cjson"},
                    {name = "lpeg",  symbol = "luaopen_lpeg"}
                }
            })

            T.assert_true(code:find("int luaopen_cjson%(lua_State %*L%);") ~= nil)
            T.assert_true(code:find("int luaopen_lpeg%(lua_State %*L%);") ~= nil)
            T.assert_true(code:find("extern int am_main%(int argc, char %*argv%[%]%);") ~= nil)
            T.assert_true(code:find("am_set_custom_init_hook%(forge_amulet_init_hook%);") ~= nil)
            T.assert_true(code:find('amulet_preload%(L, luaopen_cjson, "cjson"%);') ~= nil)
            T.assert_true(code:find('amulet_preload%(L, luaopen_lpeg, "lpeg"%);') ~= nil)
            T.assert_true(code:find("return am_main%(argc, argv%);") ~= nil)
        end
    })

    table.insert(tests, {
        name = "amulet rule discovers native modules dynamically via forge lua module tree",
        func = function ()
            local content_game = io.readfile("rules/engine/amulet/game.lua")
            T.assert_true(content_game:find('KNOWN_NATIVE_MODULES') == nil, "Should not maintain a hardcoded list")
            T.assert_true(content_game:find('lua_module%.roots_of') ~= nil, "Should use lua_module.roots_of")
            T.assert_true(content_game:find('lua_module%.bundle_sources') ~= nil, "Should use lua_module.bundle_sources")
        end
    })

    return tests
end
