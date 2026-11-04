-- Unit Tests: Compile-to-Lua Transpiler Rules (Fennel, MoonScript, YueScript, Erde, Pallene, Pluto, TypeScript, CSharp, PureScript)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "fennel rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/fennel/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.fennel"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.fnl"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "moonscript rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/moonscript/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.moonscript"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.moon"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "yuescript rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/yuescript/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.yuescript"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.yue"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "haxe rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/haxe/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.haxe"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%(') ~= nil)
            local haxe_mod = io.readfile(path.join(os.projectdir(), "modules/lang/haxe.lua"))
            T.assert_not_nil(haxe_mod)
            T.assert_true(haxe_mod:find("find_program") ~= nil)
            T.assert_true(haxe_mod:find("build_argv") ~= nil)
            T.assert_true(haxe_mod:find("backend") ~= nil)
            T.assert_true(haxe_mod:find("no%-compilation") ~= nil)
        end
    })

    table.insert(tests, {
        name = "erde rule and module exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/erde/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.erde"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.erde"%)') ~= nil)
            local erde_mod = io.readfile(path.join(os.projectdir(), "modules/lang/erde.lua"))
            T.assert_not_nil(erde_mod)
            T.assert_true(erde_mod:find("find_program") ~= nil)
            T.assert_true(erde_mod:find("test") ~= nil)
        end
    })

    table.insert(tests, {
        name = "pallene rule and module exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/pallene/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.pallene"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.pln"%)') ~= nil)
            local pallene_mod = io.readfile(path.join(os.projectdir(), "modules/lang/pallene.lua"))
            T.assert_not_nil(pallene_mod)
            T.assert_true(pallene_mod:find("find_program") ~= nil)
            T.assert_true(pallene_mod:find("emit") ~= nil)
            T.assert_true(pallene_mod:find("test") ~= nil)
        end
    })

    table.insert(tests, {
        name = "pluto rule and module exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/pluto/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.pluto"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.pluto"%)') ~= nil)
            local pluto_mod = io.readfile(path.join(os.projectdir(), "modules/lang/pluto.lua"))
            T.assert_not_nil(pluto_mod)
            T.assert_true(pluto_mod:find("find_program") ~= nil)
            T.assert_true(pluto_mod:find("find_compiler") ~= nil)
            T.assert_true(pluto_mod:find("test") ~= nil)
        end
    })

    table.insert(tests, {
        name = "typescript rule and module exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/typescript/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.typescript"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.ts"%)') ~= nil)
            local ts_mod = io.readfile(path.join(os.projectdir(), "modules/lang/typescript.lua"))
            T.assert_not_nil(ts_mod)
            T.assert_true(ts_mod:find("find_program") ~= nil)
            T.assert_true(ts_mod:find("test") ~= nil)
        end
    })

    table.insert(tests, {
        name = "csharp rule and module exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/csharp/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.csharp"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.cs"%)') ~= nil)
            local cs_mod = io.readfile(path.join(os.projectdir(), "modules/lang/csharp.lua"))
            T.assert_not_nil(cs_mod)
            T.assert_true(cs_mod:find("find_program") ~= nil)
            T.assert_true(cs_mod:find("test") ~= nil)
        end
    })

    table.insert(tests, {
        name = "purescript rule and module exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/purescript/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('rule%("recudo%.lang%.purescript"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.purs"%)') ~= nil)
            local ps_mod = io.readfile(path.join(os.projectdir(), "modules/lang/purescript.lua"))
            T.assert_not_nil(ps_mod)
            T.assert_true(ps_mod:find("find_program") ~= nil)
            T.assert_true(ps_mod:find("test") ~= nil)
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

            local tmpdir = path.join(os.tmpdir(), "recudo_test_fennel")
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
