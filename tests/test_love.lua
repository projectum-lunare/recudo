-- Unit Tests: LÖVE 2D Game Rule (forge.love)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

import("modules.template", {rootdir = os.projectdir()})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "love rule files exist and define expected rule names",
        func = function ()
            local content_xmake = io.readfile("rules/love/xmake.lua")
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find("game.lua") ~= nil)

            local content_game = io.readfile("rules/love/game.lua")
            T.assert_not_nil(content_game)
            T.assert_true(content_game:find('setup_love_rule%("forge%.love"%)') ~= nil)
            T.assert_true(content_game:find('setup_love_rule%("forge%.love%.game"%)') ~= nil)
            T.assert_true(content_game:find('setup_love_rule%("forge%.lua%.love"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "love launcher template preloads native C modules and LÖVE",
        func = function ()
            local content_game = io.readfile("rules/love/game.lua")
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
            T.assert_true(code:find("int luaopen_love%(lua_State %*L%);") ~= nil)
            T.assert_true(code:find('love_preload%(L, luaopen_cjson, "cjson"%);') ~= nil)
            T.assert_true(code:find('love_preload%(L, luaopen_lpeg, "lpeg"%);') ~= nil)
            T.assert_true(code:find('love_preload%(L, luaopen_love, "love"%);') ~= nil)
            T.assert_true(code:find('require "love.boot"') ~= nil)
        end
    })

    table.insert(tests, {
        name = "love rule discovers native modules dynamically via forge lua module tree",
        func = function ()
            local content_game = io.readfile("rules/love/game.lua")
            -- Verify it uses dynamic tree inspection rather than hardcoded tables
            T.assert_true(content_game:find('KNOWN_NATIVE_MODULES') == nil, "Should not maintain a hardcoded list")
            T.assert_true(content_game:find('lua_module%.roots_of') ~= nil, "Should use lua_module.roots_of")
            T.assert_true(content_game:find('lua_module%.bundle_sources') ~= nil, "Should use lua_module.bundle_sources")
        end
    })

    return tests
end
