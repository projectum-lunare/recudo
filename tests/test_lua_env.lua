-- Unit Tests: Lua Environment & Module Path Resolution

import("lua.env", {rootdir = "modules"})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "get_module_name resolves simple and nested files",
        func = function ()
            T.assert_equal(env.get_module_name("main.lua"), "main")
            T.assert_equal(env.get_module_name("foo.lua"), "foo")
            T.assert_equal(env.get_module_name("foo/bar.lua"), "foo.bar")
            T.assert_equal(env.get_module_name("foo/bar/baz.lua"), "foo.bar.baz")
        end
    })

    table.insert(tests, {
        name = "get_module_name handles package init files correctly",
        func = function ()
            T.assert_equal(env.get_module_name("foo/init.lua"), "foo")
            T.assert_equal(env.get_module_name("foo/bar/init.lua"), "foo.bar")
            T.assert_equal(env.get_module_name("a/b/c/init.lua"), "a.b.c")
            -- Root init.lua should remain "init"
            T.assert_equal(env.get_module_name("init.lua"), "init")
        end
    })

    table.insert(tests, {
        name = "get_module_name handles Windows backslashes",
        func = function ()
            T.assert_equal(env.get_module_name("foo\\bar.lua"), "foo.bar")
            T.assert_equal(env.get_module_name("foo\\bar\\init.lua"), "foo.bar")
            T.assert_equal(env.get_module_name("src\\foo\\bar.lua"), "src.foo.bar")
        end
    })

    table.insert(tests, {
        name = "get_relative_path strips standard root prefixes",
        func = function ()
            T.assert_equal(env.get_relative_path(nil, "src/main.lua"), "main.lua")
            T.assert_equal(env.get_relative_path(nil, "src/core/app.lua"), "core/app.lua")
            T.assert_equal(env.get_relative_path(nil, "lua/plugin/init.lua"), "plugin/init.lua")
            T.assert_equal(env.get_relative_path(nil, "lib/compat/posix.lua"), "compat/posix.lua")
            -- Windows backslashes
            T.assert_equal(env.get_relative_path(nil, "src\\core\\app.lua"), "core/app.lua")
            T.assert_equal(env.get_relative_path(nil, "lua\\plugin\\init.lua"), "plugin/init.lua")
        end
    })

    table.insert(tests, {
        name = "get_lua_paths contains project structure and system fallback",
        func = function ()
            local p = env.get_lua_paths("/tmp/test_project", "5.4")
            T.assert_true(p:find("/tmp/test_project/src/%?%.lua", 1, false) ~= nil, "src/?.lua should be in LUA_PATH")
            T.assert_true(p:find("/tmp/test_project/build/lua/%?%.lua", 1, false) ~= nil, "build/lua/?.lua should be in LUA_PATH")
            T.assert_true(p:find(";;", 1, true) ~= nil, "LUA_PATH should end with ;; system fallback")
        end
    })

    table.insert(tests, {
        name = "get_lua_cpaths contains binary module paths",
        func = function ()
            local cp = env.get_lua_cpaths("/tmp/test_project", "5.4")
            local ext = (os.host() == "windows") and "dll" or "so"
            T.assert_true(cp:find("/tmp/test_project/build/lua/%?%." .. ext, 1, false) ~= nil, "build/lua/*.so should be in LUA_CPATH")
            T.assert_true(cp:find(";;", 1, true) ~= nil, "LUA_CPATH should end with ;; system fallback")
        end
    })

    return tests
end
