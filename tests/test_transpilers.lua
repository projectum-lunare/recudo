-- Unit Tests: Compile-to-Lua Transpiler Rules (Fennel, MoonScript, YueScript)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "fennel rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile("rules/fennel/xmake.lua")
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('setup_fennel_rule%("forge%.fennel"%)') ~= nil)
            T.assert_true(content_xmake:find('setup_fennel_rule%("forge%.lua%.fennel"%)') ~= nil)
            T.assert_true(content_xmake:find('setup_fennel_rule%("fennel"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.fnl"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "moonscript rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile("rules/moonscript/xmake.lua")
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('setup_moonscript_rule%("forge%.moonscript"%)') ~= nil)
            T.assert_true(content_xmake:find('setup_moonscript_rule%("forge%.lua%.moonscript"%)') ~= nil)
            T.assert_true(content_xmake:find('setup_moonscript_rule%("moonscript"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.moon"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "yuescript rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile("rules/yuescript/xmake.lua")
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('setup_yuescript_rule%("forge%.yuescript"%)') ~= nil)
            T.assert_true(content_xmake:find('setup_yuescript_rule%("forge%.lua%.yuescript"%)') ~= nil)
            T.assert_true(content_xmake:find('setup_yuescript_rule%("yuescript"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.yue"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "fennel compiler transpiles lisp s-expressions into valid lua",
        func = function ()
            import("lib.detect.find_tool")
            local tool = find_tool("fennel")
            if not tool or not tool.program then
                return
            end

            local tmpdir = path.join(os.tmpdir(), "forge_test_fennel")
            os.rm(tmpdir)
            os.mkdir(tmpdir)

            local fnl_file = path.join(tmpdir, "math.fnl")
            local lua_file = path.join(tmpdir, "math.lua")
            io.writefile(fnl_file, "(fn add [a b] (+ a b))\n(print (add 10 20))")

            os.vrunv(tool.program, {"--compile", fnl_file}, {stdout = lua_file})
            T.assert_true(os.isfile(lua_file), "Transpiled lua output exists")

            local lua_code = io.readfile(lua_file)
            T.assert_true(lua_code:find("add") ~= nil, "Generated lua contains function")
            T.assert_true(lua_code:find("print") ~= nil, "Generated lua contains print")

            os.rm(tmpdir)
        end
    })

    return tests
end
