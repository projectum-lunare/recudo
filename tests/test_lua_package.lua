-- Unit and integration tests: Lua modules installed from xmake package recipes

local lua_module = import("lua.module", {rootdir = "modules", anonymous = true})
import("lua.env", {rootdir = "modules"})
import("lua.bundler", {rootdir = "modules"})

local function fake_package(plat, shared)
    return {
        plat = function()
            return plat
        end,
        config = function(_, name)
            if name == "shared" then
                return shared
            end
        end
    }
end

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "open_symbol and link_name sanitize module names",
        func = function ()
            T.assert_equal(lua_module.open_symbol("forge.native"), "luaopen_forge_native")
            T.assert_equal(lua_module.open_symbol("socket.core"), "luaopen_socket_core")
            T.assert_equal(lua_module.link_name("foo-bar.baz"), "foo_bar_baz")
        end
    })

    table.insert(tests, {
        name = "module paths follow require lookup",
        func = function ()
            T.assert_equal(lua_module.module_lua_relpath("forge.hello", "hello.lua"), "forge/hello.lua")
            T.assert_equal(lua_module.module_lua_relpath("forge.hello", "hello/init.lua"), "forge/hello/init.lua")
            T.assert_equal(lua_module.module_c_relpath("forge.native", "so"), "forge/native.so")
            T.assert_equal(lua_module.module_c_relpath("cjson", ".dll"), "cjson.dll")
        end
    })

    table.insert(tests, {
        name = "link mode follows shared and platforms that cannot dlopen stay static",
        func = function ()
            T.assert_true(lua_module.prefers_static(fake_package("linux", nil)))
            T.assert_true(lua_module.prefers_static(fake_package("linux", false)))
            T.assert_false(lua_module.prefers_static(fake_package("linux", true)))
            T.assert_true(lua_module.prefers_static(fake_package("dos", true)))
            T.assert_true(lua_module.prefers_static(fake_package("wince", true)))
            T.assert_true(lua_module.prefers_static(fake_package("wasm", true)))
            T.assert_false(lua_module.supports_dynamic("wasm"))
            T.assert_true(lua_module.supports_dynamic("linux"))
        end
    })

    table.insert(tests, {
        name = "install writes a pure Lua module manifest",
        func = function ()
            local root = path.join(os.tmpdir(), "forge_lua_pkg_unit")
            os.tryrm(root)
            os.mkdir(root)
            local src = path.join(root, "hello.lua")
            local installdir = path.join(root, "install")
            io.writefile(src, "return {answer = 42}\n")
            os.mkdir(installdir)

            local pkg = {
                installdir = function()
                    return installdir
                end
            }
            lua_module.install(pkg, {
                modules = {
                    ["forge.hello"] = src,
                    ["forge.inline"] = "return {inline = true}\n"
                }
            })

            local manifest = lua_module.load_manifest(installdir)
            T.assert_not_nil(manifest)
            T.assert_equal(manifest.luaver, "5.4")
            T.assert_equal(manifest.modules[1].name, "forge.hello")
            T.assert_equal(manifest.modules[1].kind, "lua")
            T.assert_true(os.isfile(path.join(installdir, manifest.modules[1].relpath)))
            T.assert_equal(manifest.modules[2].name, "forge.inline")
            T.assert_true(os.isfile(path.join(installdir, "share/lua/5.4/forge/inline.lua")))

            local patterns = lua_module.search_patterns({installdir}, "path")
            T.assert_true(#patterns >= 1, "pure Lua package should publish a LUA_PATH pattern")
            T.assert_true(patterns[1]:find("share/lua/5.4/%?%.lua", 1, false) ~= nil, patterns[1])

            local paths = env.get_lua_paths(root, "5.4", {package_roots = {installdir}, inherit_env = false})
            T.assert_true(paths:find("share/lua/5.4/%?%.lua", 1, false) ~= nil, "LUA_PATH should include the package")
            T.assert_true(paths:endswith(";;"), "LUA_PATH should keep the system fallback")
            local closed = env.get_lua_paths(root, "5.4", {sandbox = true, inherit_env = false})
            T.assert_true(closed:find(";;", 1, true) == nil, "sandbox LUA_PATH must not reopen the system path")

            local bundled = lua_module.bundle_sources({installdir})
            T.assert_equal(bundled.module_map[bundled.files[1]], "forge.hello")
            local code = bundler.generate_bundle_source(bundled.files, {
                entry_module = "main",
                file_map = bundled.file_map,
                module_map = bundled.module_map,
                native_modules = {{name = "forge.native", symbol = "luaopen_forge_native"}},
                cpath = installdir .. "/lib/lua/5.4/?.so",
                include_main = true
            })
            T.assert_true(code:find("luaopen_forge_native") ~= nil, "bundle should declare the static luaopen symbol")
            T.assert_true(code:find("forge%.native") ~= nil, "bundle should preload the native module name")
            T.assert_true(code:find("package") ~= nil and code:find("cpath") ~= nil, "bundle should set package.cpath")
            os.tryrm(root)
        end
    })

    table.insert(tests, {
        name = "forge.lua.bin installs a Lua program into bin",
        func = function ()
            local root = path.join(os.tmpdir(), "forge_lua_bin")
            local prefix = path.join(root, "prefix")
            os.tryrm(root)
            os.mkdir(path.join(root, "src"))
            os.mkdir(path.join(root, "src", "bin"))
            local forge_lua = path.join(os.projectdir(), "includes", "forge.lua")
            io.writefile(path.join(root, "src", "bin", "tool"), "#!/usr/bin/env lua\nprint('forge-bin-ok')\n")
            io.writefile(path.join(root, "xmake.lua"), string.format([[
set_project("forge_lua_bin")
includes(%q)

target("tool")
    add_rules("forge.lua.bin")
    add_files("src/bin/tool")
]], forge_lua))
            local xmake_opt = {curdir = root}
            os.execv("xmake", {"f", "-c", "-y", "-m", "release"}, xmake_opt)
            os.execv("xmake", {"install", "-y", "-o", prefix}, xmake_opt)
            local bin = path.join(prefix, "bin", "tool")
            T.assert_true(os.isexec(bin), "installed Lua program should be executable")
            local out = os.iorunv(bin, {})
            T.assert_true(out:find("forge-bin-ok", 1, true) ~= nil, out)
            os.tryrm(root)
        end
    })

    table.insert(tests, {
        name = "shared mode runs the Lua app against shared recipes",
        func = function ()
            local root = path.join(os.tmpdir(), "forge_lua_pkg_app")
            os.tryrm(root)
            os.mkdir(path.join(root, "src"))
            local forge_lua = path.join(os.projectdir(), "includes", "forge.lua")
            io.writefile(path.join(root, "src", "main.lua"), [[
local hello = require("forge.hello")
local native = require("forge.native")
if hello.answer() ~= 42 then error("hello") end
if native ~= 7 then error("native=" .. tostring(native)) end
print("forge-pkg-ok")
]])
            io.writefile(path.join(root, "xmake.lua"), string.format([[
set_project("forge_lua_pkg_app")
includes(%q)
add_requires("lua", {system = false})
add_requires("forge-hello", "forge-native")

target("app")
    set_kind("phony")
    add_rules("forge.lua.app")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("lua", "forge-hello", "forge-native")

target("bundled")
    set_default(false)
    add_rules("forge.lua.bundle")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("lua", "forge-hello", "forge-native")
]], forge_lua))

            local xmake_opt = {curdir = root}
            os.execv("xmake", {"f", "-c", "-y", "-m", "release", "--kind=shared"}, xmake_opt)
            os.execv("xmake", {"build", "app"}, xmake_opt)
            local app_out = os.iorunv("xmake", {"run", "app"}, xmake_opt)
            T.assert_true(app_out:find("forge-pkg-ok", 1, true) ~= nil, app_out)
            os.tryrm(root)
        end
    })

    table.insert(tests, {
        name = "pure Lua app loads a C recipe inside the private interpreter",
        func = function ()
            local root = path.join(os.tmpdir(), "forge_lua_sandbox_app")
            os.tryrm(root)
            os.mkdir(path.join(root, "src"))
            local forge_lua = path.join(os.projectdir(), "includes", "forge.lua")
            io.writefile(path.join(root, "src", "main.lua"), [[
local native = require("forge.native")
if native ~= 7 then error("native=" .. tostring(native)) end
if package.path:find("/usr/", 1, true) or package.cpath:find("/usr/", 1, true) then
    error("sandbox leaked\n" .. package.path .. "\n" .. package.cpath)
end
if not package.cpath:find(".runtime", 1, true) then
    error("module was not loaded from the staged runtime: " .. package.cpath)
end
print("forge-sandbox-ok")
]])
            io.writefile(path.join(root, "xmake.lua"), string.format([[
set_project("forge_lua_sandbox_app")
includes(%q)
add_requires("forge-native")

target("app")
    set_kind("phony")
    add_rules("forge.lua.app")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("forge-native")
]], forge_lua))

            local xmake_opt = {curdir = root}
            os.execv("xmake", {"f", "-c", "-y", "-m", "release", "--kind=shared"}, xmake_opt)
            os.execv("xmake", {"build", "app"}, xmake_opt)
            local app_out = os.iorunv("xmake", {"run", "app"}, xmake_opt)
            T.assert_true(app_out:find("forge-sandbox-ok", 1, true) ~= nil, app_out)
            local launcher = io.readfile(path.join(root, "build/bin/app"))
            T.assert_true(launcher:find("LD_LIBRARY_PATH", 1, true) == nil, "launcher must not point at the package cache")
            T.assert_true(launcher:find("app.runtime", 1, true) ~= nil, launcher)
            T.assert_true(launcher:find("$RUNTIME/bin/lua", 1, true) ~= nil, launcher)
            local wrapper = io.readfile(path.join(root, "build/bin/app.runtime/bin/lua"))
            T.assert_true(wrapper:find("$SELF/../lib", 1, true) ~= nil, wrapper)
            T.assert_true(os.isfile(path.join(root, "build/bin/app.runtime/lib/liblua.so")))
            local runtime_note = io.readfile(os.files(path.join(root, "build/.packages/f/forge-native/**/lua-runtime.lua"))[1])
            T.assert_true(runtime_note:find("installdir", 1, true) ~= nil, "runtime descriptor must record the lua installdir")
            T.assert_true(runtime_note:find("buildhash", 1, true) == nil, "runtime descriptor must not rebuild a cache path")
            os.tryrm(root)
        end
    })

    table.insert(tests, {
        name = "static mode links the C recipe into the bundle",
        func = function ()
            local root = path.join(os.tmpdir(), "forge_lua_static_app")
            os.tryrm(root)
            os.mkdir(path.join(root, "src"))
            local forge_lua = path.join(os.projectdir(), "includes", "forge.lua")
            io.writefile(path.join(root, "src", "main.lua"), [[
local native = require("forge.native")
if native ~= 7 then error("native=" .. tostring(native)) end
print("forge-static-ok")
]])
            io.writefile(path.join(root, "xmake.lua"), string.format([[
set_project("forge_lua_static_app")
includes(%q)
add_requires("lua", {system = false})
add_requires("forge-native")

target("bundled")
    add_rules("forge.lua.bundle")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("lua", "forge-native")
]], forge_lua))

            local xmake_opt = {curdir = root}
            os.execv("xmake", {"f", "-c", "-y", "-m", "release", "--kind=static"}, xmake_opt)
            os.execv("xmake", {"build", "bundled"}, xmake_opt)
            local bundle_out = os.iorunv("xmake", {"run", "bundled"}, xmake_opt)
            T.assert_true(bundle_out:find("forge-static-ok", 1, true) ~= nil, bundle_out)
            T.assert_true(not os.isdir(path.join(root, "build/bin/bundled.runtime")))
            os.tryrm(root)
        end
    })

    table.insert(tests, {
        name = "setup_runtime orchestrates Lua runtimes and version constraints",
        func = function ()
            local added_deps = {}
            local fake_pkg = {
                name = function() return "test-pkg" end,
                config = function(_, k)
                    if k == "runtime" then return "lua" end
                end,
                add = function(_, kind, dep, opt)
                    table.insert(added_deps, {kind = kind, dep = dep, opt = opt})
                end
            }

            -- Test { runtime = {"lua", "luajit"}, version = ">=5.1 <=5.3" }
            lua_module.setup(fake_pkg, {runtime = {"lua", "luajit"}, version = ">=5.1 <=5.3"})
            T.assert_equal(#added_deps, 2)
            T.assert_equal(added_deps[1].dep, "lua >=5.1 <=5.3")
            T.assert_equal(added_deps[2].dep, "forge master")

            -- Test string shorthand syntax setup(pkg, ">=5.1 <=5.3")
            added_deps = {}
            lua_module.setup(fake_pkg, ">=5.1 <=5.3")
            T.assert_equal(#added_deps, 2)
            T.assert_equal(added_deps[1].dep, "lua >=5.1 <=5.3")

            -- Test single runtime setup(pkg, {runtime = "luajit"})
            added_deps = {}
            local fake_single_pkg = {
                name = function() return "test-magick" end,
                config = function() end,
                add = function(_, kind, dep, opt)
                    table.insert(added_deps, {kind = kind, dep = dep, opt = opt})
                end
            }
            lua_module.setup(fake_single_pkg, {runtime = "luajit"})
            T.assert_equal(#added_deps, 2)
            T.assert_equal(added_deps[1].dep, "luajit")

            -- Test LuaJIT runtime selection with multi-runtime definition
            added_deps = {}
            local fake_jit_pkg = {
                name = function() return "test-jit" end,
                config = function(_, k)
                    if k == "runtime" then return "luajit" end
                end,
                add = function(_, kind, dep, opt)
                    table.insert(added_deps, {kind = kind, dep = dep, opt = opt})
                end
            }
            lua_module.setup(fake_jit_pkg, {runtime = {"lua", "luajit"}})
            T.assert_equal(#added_deps, 2)
            T.assert_equal(added_deps[1].dep, "luajit")
            T.assert_equal(added_deps[2].dep, "forge master")

            -- Test unsupported runtime rejection
            local fake_unsupported_pkg = {
                name = function() return "test-unsupported" end,
                config = function(_, k)
                    if k == "runtime" then return "luau" end
                end,
                add = function() end
            }
            local err_unsupported = nil
            try {
                function ()
                    lua_module.setup(fake_unsupported_pkg, {runtime = {"lua", "luajit"}})
                end,
                catch {
                    function (err)
                        err_unsupported = err
                    end
                }
            }
            T.assert_true(err_unsupported ~= nil, "should fail for unsupported runtime")
            T.assert_true(err_unsupported:find("does not support runtime 'luau'") ~= nil, err_unsupported)

            -- Test incompatible version rejection
            local fake_incompat_pkg = {
                name = function() return "test-incompat" end,
                config = function(_, k)
                    if k == "runtime" then return "lua" end
                    if k == "lua_version" then return "5.4.7" end
                end,
                add = function() end
            }
            local err_msg = nil
            try {
                function ()
                    lua_module.setup(fake_incompat_pkg, {runtime = {"lua", "luajit"}, version = ">=5.1 <=5.3"})
                end,
                catch {
                    function (err)
                        err_msg = err
                    end
                }
            }
            T.assert_true(err_msg ~= nil, "should fail for incompatible Lua 5.4.7")
            T.assert_true(err_msg:find("only supports Lua >=5.1 <=5.3 or LuaJIT") ~= nil, err_msg)
        end
    })

    return tests
end
