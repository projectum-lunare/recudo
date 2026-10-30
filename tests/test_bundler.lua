-- Unit Tests: Lua Application Bundler & C Code Generation

import("lua.bundler", {rootdir = "modules"})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "generate_bundle_source creates valid C bundle",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "forge_test_mod.lua")
            io.writefile(temp_lua, 'print("Hello from bundled Lua")\nreturn {status = "ok"}')

            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "forge_test_mod",
                include_main = true
            })

            os.rm(temp_lua)

            T.assert_not_nil(c_code)
            T.assert_true(c_code:find("#%s*include%s*<lua%.h>") ~= nil or c_code:find("#%s*include%s*<lua/lua%.h>") ~= nil, "Should include lua.h")
            T.assert_true(c_code:find("forge_lua_data_1") ~= nil, "Should define data array")
            T.assert_true(c_code:find("forge_preload_1") ~= nil, "Should define preload loader")
            T.assert_true(c_code:find("forge_lua_preload_all") ~= nil, "Should define preload_all function")
            T.assert_true(c_code:find("int main%(int argc, char %*%*argv%)") ~= nil, "Should define main function")
            T.assert_true(c_code:find('require.*forge_test_mod') ~= nil, "Main should require entry module")
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source preloads native luaopen symbols",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "forge_test_mod.lua")
            io.writefile(temp_lua, "return true\n")
            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                native_modules = {{name = "forge.native", symbol = "luaopen_forge_native"}},
                cpath = "/opt/forge/?.so"
            })
            os.rm(temp_lua)
            T.assert_true(c_code:find("extern int luaopen_forge_native%(lua_State %*L%)") ~= nil, "Should declare luaopen")
            T.assert_true(c_code:find('lua_setfield%(L, %-2, "forge%.native"%)') ~= nil, "Should preload forge.native")
            T.assert_true(c_code:find('/opt/forge/%?%.so') ~= nil, "Should embed cpath")
        end
    })

    return tests
end
