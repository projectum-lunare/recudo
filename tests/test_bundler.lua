-- Unit Tests: Lua Application Bundler & C Code Generation
-- Supports both source code embedding and target-aware bytecode cross-compilation

import("lua.bundler", {rootdir = "modules"})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "generate_bundle_source creates valid C bundle",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_mod.lua")
            io.writefile(temp_lua, 'print("Hello from bundled Lua")\nreturn {status = "ok"}')

            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "recudo_test_mod",
                include_main = true
            })

            os.rm(temp_lua)

            T.assert_not_nil(c_code)
            T.assert_true(c_code:find("#%s*include%s*<lua%.h>") ~= nil or c_code:find("#%s*include%s*<lua/lua%.h>") ~= nil, "Should include lua.h")
            T.assert_true(c_code:find("recudo_lua_data_1") ~= nil, "Should define data array")
            T.assert_true(c_code:find("recudo_preload_1") ~= nil, "Should define preload loader")
            T.assert_true(c_code:find("recudo_lua_preload_all") ~= nil, "Should define preload_all function")
            T.assert_true(c_code:find("int main%(int argc, char %*%*argv%)") ~= nil, "Should define main function")
            T.assert_true(c_code:find('require.*recudo_test_mod') ~= nil, "Main should require entry module")
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source preloads native luaopen symbols",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_mod.lua")
            io.writefile(temp_lua, "return true\n")
            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                native_modules = {{name = "recudo.native", symbol = "luaopen_recudo_native"}},
                cpath = "/opt/recudo/?.so"
            })
            os.rm(temp_lua)
            T.assert_true(c_code:find("extern int luaopen_recudo_native%(lua_State %*L%)") ~= nil, "Should declare luaopen")
            T.assert_true(c_code:find('lua_setfield%(L, %-2, "recudo%.native"%)') ~= nil, "Should preload recudo.native")
            T.assert_true(c_code:find('/opt/recudo/%?%.so') ~= nil, "Should embed cpath")
        end
    })

    table.insert(tests, {
        name = "resolve_profile respects explicit options and target defines",
        func = function ()
            local endian, bits = bundler.resolve_profile({endian = "be", bits = 32})
            T.assert_equal(endian, "be")
            T.assert_equal(bits, 32)

            endian, bits = bundler.resolve_profile({endian = "le", bits = 64})
            T.assert_equal(endian, "le")
            T.assert_equal(bits, 64)

            endian, bits = bundler.resolve_profile({bits32 = true})
            T.assert_equal(bits, 32)

            -- Mock target with defines
            local mock_target = {
                is_plat = function() return false end,
                get = function(self, key)
                    if key == "defines" then return {"LUA_32BITS", "LUA_BIG_ENDIAN"} end
                    return nil
                end,
                values = function() return nil end
            }
            endian, bits = bundler.resolve_profile(mock_target)
            T.assert_equal(endian, "be")
            T.assert_equal(bits, 32)
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source supports custom preload function name",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_fn.lua")
            io.writefile(temp_lua, "return 42\n")

            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                preload_function = "my_custom_preload_func"
            })
            os.rm(temp_lua)

            T.assert_true(c_code:find("void my_custom_preload_func%(lua_State %*L%)") ~= nil, "Should define custom preload function")
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source supports bytecode mode across endianness and bits",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_bc.lua")
            io.writefile(temp_lua, "local x = 10\nlocal y = 20\nreturn x + y\n")

            -- 1. Little-Endian 64-bit
            local c_le64 = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "test_bc",
                mode = "bytecode",
                endian = "le",
                bits = 64
            })
            T.assert_not_nil(c_le64)
            -- Check Lua signature \x1bLua: 0x1b, 0x4c, 0x75, 0x61
            T.assert_true(c_le64:find("0x1b, 0x4c, 0x75, 0x61") ~= nil, "LE64 should contain Lua bytecode header")

            -- 2. Little-Endian 32-bit (WinCE, DOS)
            local c_le32 = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "test_bc",
                mode = "bytecode",
                endian = "le",
                bits = 32
            })
            T.assert_not_nil(c_le32)
            T.assert_true(c_le32:find("0x1b, 0x4c, 0x75, 0x61") ~= nil, "LE32 should contain Lua bytecode header")

            -- 3. Big-Endian 32-bit (Amiga, Atari)
            local c_be32 = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "test_bc",
                mode = "bytecode",
                endian = "be",
                bits = 32
            })
            T.assert_not_nil(c_be32)
            T.assert_true(c_be32:find("0x1b, 0x4c, 0x75, 0x61") ~= nil, "BE32 should contain Lua bytecode header")

            os.rm(temp_lua)
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source supports state_init for custom state initialization",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_init.lua")
            io.writefile(temp_lua, "return {run = function(arg) return 0 end}\n")

            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "cli",
                state_init = "dotstar_new_state"
            })
            os.rm(temp_lua)

            T.assert_not_nil(c_code)
            T.assert_true(c_code:find("extern lua_State %*dotstar_new_state%(void%);") ~= nil, "Should declare state_init")
            T.assert_true(c_code:find("lua_State %*L = dotstar_new_state%(%);") ~= nil, "Should invoke state_init")
            T.assert_true(c_code:find("recudo_lua_preload_all%(L%);") ~= nil, "Should register preloaded modules on L")
            T.assert_true(c_code:find('lua_getfield%(L, %-1, "run"%);') ~= nil, "Should invoke table.run")
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source supports selective lua_libs",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_libs.lua")
            io.writefile(temp_lua, "return 0\n")

            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                lua_libs = {"base", "table", "string", "utf8"}
            })
            os.rm(temp_lua)

            T.assert_not_nil(c_code)
            T.assert_true(c_code:find('luaL_requiref%(L, "_G", luaopen_base, 1%);') ~= nil, "Should load base")
            T.assert_true(c_code:find('luaL_requiref%(L, "table", luaopen_table, 1%);') ~= nil, "Should load table")
            T.assert_true(c_code:find('luaL_requiref%(L, "string", luaopen_string, 1%);') ~= nil, "Should load string")
            T.assert_true(c_code:find('luaL_requiref%(L, "utf8", luaopen_utf8, 1%);') ~= nil, "Should load utf8")
            T.assert_true(c_code:find('luaopen_math') == nil, "Should NOT load math")
            T.assert_true(c_code:find('luaL_openlibs') == nil, "Should NOT call luaL_openlibs")
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source supports lua_libs_exclude blocklist",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_ex.lua")
            io.writefile(temp_lua, "return 0\n")

            local c_code = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                lua_libs_exclude = {"math", "os", "debug"}
            })
            os.rm(temp_lua)

            T.assert_not_nil(c_code)
            -- Should load non-excluded libraries
            T.assert_true(c_code:find('luaL_requiref%(L, "_G", luaopen_base, 1%);') ~= nil, "Should load base")
            T.assert_true(c_code:find('luaL_requiref%(L, "table", luaopen_table, 1%);') ~= nil, "Should load table")
            T.assert_true(c_code:find('luaL_requiref%(L, "string", luaopen_string, 1%);') ~= nil, "Should load string")
            T.assert_true(c_code:find('luaL_requiref%(L, "io", luaopen_io, 1%);') ~= nil, "Should load io")
            T.assert_true(c_code:find('luaL_requiref%(L, "utf8", luaopen_utf8, 1%);') ~= nil, "Should load utf8")
            -- Should NOT load excluded libraries
            T.assert_true(c_code:find('luaopen_math') == nil, "Should NOT load math")
            T.assert_true(c_code:find('luaopen_os') == nil, "Should NOT load os")
            T.assert_true(c_code:find('luaopen_debug') == nil, "Should NOT load debug")
        end
    })

    table.insert(tests, {
        name = "generate_bundle_source respects parser flag and stubs",
        func = function ()
            local temp_lua = path.join(os.tmpdir(), "recudo_test_parser.lua")
            io.writefile(temp_lua, "return 1\n")

            -- 1. Default (parser enabled): No parser stubs generated
            local c_with_parser = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                parser = true
            })
            T.assert_true(c_with_parser:find("luaY_parser") == nil, "Parser stubs should not be present when parser is enabled")
            T.assert_true(c_with_parser:find("luaU_dump") == nil, "Dump stubs should not be present when parser is enabled")

            -- 2. Parser disabled: Generates stubs for luaX_init, luaY_parser, luaU_dump
            local c_no_parser = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                parser = false
            })
            T.assert_true(c_no_parser:find("void luaX_init%(lua_State %*L%)") ~= nil, "Should define luaX_init stub")
            T.assert_true(c_no_parser:find("void %*luaY_parser") ~= nil, "Should define luaY_parser stub")
            T.assert_true(c_no_parser:find("int luaU_dump") ~= nil, "Should define luaU_dump stub")

            -- 3. Mock target with LUA_NO_PARSER define
            local mock_target = {
                is_plat = function() return false end,
                get = function(self, key)
                    if key == "defines" then return {"LUA_NO_PARSER"} end
                    return nil
                end,
                values = function() return nil end
            }
            local c_target_no_parser = bundler.generate_bundle_source({temp_lua}, {
                entry_module = "main",
                target = mock_target
            })
            T.assert_true(c_target_no_parser:find("void %*luaY_parser") ~= nil, "Should define luaY_parser stub via target defines")

            os.rm(temp_lua)
        end
    })

    return tests
end
