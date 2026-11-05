-- Unit Tests: Lua C-Library Generator & C ABI Bindings
-- Tests header emission, bridge generation, context management, and type marshalling.

import("lua.clib_generator", {rootdir = "modules"})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "clib rule files exist and define expected rule names",
        func = function ()
            local rule_file = path.join(os.projectdir(), "rules/lua/clib.lua")
            T.assert_true(os.isfile(rule_file), "rules/lua/clib.lua must exist")
            local content = io.readfile(rule_file)
            T.assert_true(content:find('rule%("recudo%.lua%.clib"%)') ~= nil or content:find('setup_clib_rule%("recudo%.lua%.clib"%)') ~= nil,
                "Rule must define recudo.lua.clib")
            T.assert_true(content:find('set_extensions%("%.lua"%)') ~= nil, "Rule should match .lua extensions")
            T.assert_true(content:find('set_sourcekinds%("cc"%)') ~= nil, "Rule should set cc sourcekind for linker")
        end
    })

    table.insert(tests, {
        name = "clib_generator generates valid C header in context mode",
        func = function ()
            local config = {
                prefix = "calc_",
                header_file = "calc.h",
                entry_module = "calc",
                mode = "context",
                exports = {
                    {
                        name = "add",
                        desc = "Adds two numbers",
                        params = { { name = "a", type = "int" }, { name = "b", type = "int" } },
                        returns = { { name = "sum", type = "int" } }
                    }
                }
            }

            local hdr = clib_generator.generate_header(config)
            T.assert_not_nil(hdr)
            T.assert_true(hdr:find("typedef struct calc_ctx calc_ctx_t;") ~= nil, "Should declare opaque context")
            T.assert_true(hdr:find("calc_ctx_t %*calc_create%(void%);") ~= nil, "Should declare create function")
            T.assert_true(hdr:find("void calc_destroy%(calc_ctx_t %*ctx%);") ~= nil, "Should declare destroy function")
            T.assert_true(hdr:find("void calc_free%(void %*ptr%);") ~= nil, "Should declare free function")
            T.assert_true(hdr:find("int calc_add%(") ~= nil, "Should declare calc_add")
            T.assert_true(hdr:find("calc_ctx_t %*ctx") ~= nil, "calc_add should take ctx as first arg")
            T.assert_true(hdr:find("int %*out_sum") ~= nil, "calc_add should have out_sum parameter")
            T.assert_true(hdr:find("char %*%*err_msg") ~= nil, "calc_add should have err_msg parameter")
        end
    })

    table.insert(tests, {
        name = "clib_generator generates stateless and both modes correctly",
        func = function ()
            local config = {
                prefix = "str_",
                header_file = "str.h",
                entry_module = "str",
                mode = "both",
                exports = {
                    {
                        name = "concat",
                        params = { { name = "a", type = "string" }, { name = "b", type = "string" } },
                        returns = { { name = "res", type = "string" } }
                    }
                }
            }

            local hdr = clib_generator.generate_header(config)
            T.assert_true(hdr:find("int str_concat%(") ~= nil, "Should declare context function")
            T.assert_true(hdr:find("int str_concat_oneshot%(") ~= nil, "Should declare stateless oneshot function")
            T.assert_true(hdr:find("char %*%*out_res") ~= nil, "Should have out_res pointer")
        end
    })

    table.insert(tests, {
        name = "clib_generator generates bridge code with memory management and error handling",
        func = function ()
            local config = {
                prefix = "img_",
                header_file = "img.h",
                entry_module = "img",
                preload_function = "img_preload",
                mode = "context",
                exports = {
                    {
                        name = "process",
                        params = {
                            { name = "data", type = "bytes" },
                            { name = "factor", type = "double" },
                            { name = "grayscale", type = "bool" }
                        },
                        returns = {
                            { name = "output", type = "bytes" },
                            { name = "width", type = "int" }
                        }
                    }
                }
            }

            local brg = clib_generator.generate_bridge(config)
            T.assert_not_nil(brg)
            T.assert_true(brg:find('#include "img%.h"') ~= nil, "Should include generated header")
            T.assert_true(brg:find("void img_preload%(lua_State %*L%);") ~= nil, "Should declare preload function")
            T.assert_true(brg:find("struct img_ctx") ~= nil, "Should define struct img_ctx")
            T.assert_true(brg:find("img_ctx_t %*img_create%(void%)") ~= nil, "Should define img_create")
            T.assert_true(brg:find("void img_destroy%(img_ctx_t %*ctx%)") ~= nil, "Should define img_destroy")
            T.assert_true(brg:find("void img_free%(void %*ptr%)") ~= nil, "Should define img_free")
            T.assert_true(brg:find("lua_pushlstring%(L, %(const char %*%)data, data_len%);") ~= nil, "Should push input bytes with len")
            T.assert_true(brg:find("lua_pushnumber%(L, %(lua_Number%)factor%);") ~= nil, "Should push factor number")
            T.assert_true(brg:find("lua_pushboolean%(L, grayscale%);") ~= nil, "Should push boolean")
            T.assert_true(brg:find("malloc%(rlen %+ 1%);") ~= nil, "Should malloc output buffer")
            T.assert_true(brg:find("%*out_output_len = rlen;") ~= nil, "Should set output length")
            T.assert_true(brg:find("%*out_width = %(int%)lua_tointeger") ~= nil, "Should extract width integer")
        end
    })

    table.insert(tests, {
        name = "clib_generator supports int64_t and C89 integer guards",
        func = function ()
            local config = {
                prefix = "big_",
                header_file = "big.h",
                entry_module = "big",
                mode = "context",
                exports = {
                    {
                        name = "calc64",
                        params = { { name = "val", type = "int64" } },
                        returns = { { name = "out", type = "int64" } }
                    }
                }
            }

            local hdr = clib_generator.generate_header(config)
            T.assert_true(hdr:find("int64_t") ~= nil, "Header should contain int64_t")
            T.assert_true(hdr:find("typedef __int64 int64_t;") ~= nil, "Header should have MSVC vintage guard")

            local brg = clib_generator.generate_bridge(config)
            T.assert_true(brg:find("lua_pushinteger%(L, %(lua_Integer%)val%);") ~= nil, "Bridge should push int64")
            T.assert_true(brg:find("%*out_out = %(int64_t%)lua_tointeger") ~= nil, "Bridge should extract int64")
        end
    })

    table.insert(tests, {
        name = "recudo.lua.clib builds a static C library from Lua and links into a C executable",
        func = function ()
            local root = path.join(os.tmpdir(), "recudo_test_clib_e2e")
            os.tryrm(root)
            os.mkdir(path.join(root, "src"))
            os.mkdir(path.join(root, "tests"))

            local recudo_lua = path.join(os.projectdir(), "includes", "recudo.lua")

            io.writefile(path.join(root, "src/adder.lua"), [[
local M = {}
function M.add(a, b)
    return a + b
end
function M.greet(name)
    return "Hello, " .. tostring(name) .. "!"
end
return M
]])

            io.writefile(path.join(root, "tests/main.c"), [[
#include <stdio.h>
#include <stdlib.h>
#include "adder.h"

int main(void) {
    adder_ctx_t *ctx = adder_create();
    if (!ctx) {
        fprintf(stderr, "Failed to create context\n");
        return 1;
    }

    int sum = 0;
    char *err = NULL;
    int rc = adder_add(ctx, 40, 2, &sum, &err);
    if (rc != ADDER_OK) {
        fprintf(stderr, "adder_add failed: %s\n", err ? err : "unknown");
        adder_free(err);
        adder_destroy(ctx);
        return 1;
    }

    char *msg = NULL;
    rc = adder_greet(ctx, "World", &msg, &err);
    if (rc != ADDER_OK) {
        fprintf(stderr, "adder_greet failed: %s\n", err ? err : "unknown");
        adder_free(err);
        adder_destroy(ctx);
        return 1;
    }

    printf("E2E SUCCESS: sum=%d msg=%s\n", sum, msg);

    adder_free(msg);
    adder_destroy(ctx);
    return 0;
}
]])

            io.writefile(path.join(root, "xmake.lua"), string.format([[
set_project("test_clib_e2e")
includes(%q)
add_requires("lua", {system = false})

target("adder")
    set_kind("static")
    add_rules("recudo.lua.clib")
    add_files("src/adder.lua")
    add_packages("lua")
    set_values("recudo.lua.clib.prefix", "adder_")
    set_values("recudo.lua.clib.header", "adder.h")
    set_values("recudo.lua.clib.entry", "adder")
    set_values("recudo.lua.clib.exports", {
        {
            name = "add",
            params = { { name = "a", type = "int" }, { name = "b", type = "int" } },
            returns = { { name = "sum", type = "int" } }
        },
        {
            name = "greet",
            params = { { name = "name", type = "string" } },
            returns = { { name = "msg", type = "string" } }
        }
    })

target("test_runner")
    set_kind("binary")
    add_files("tests/main.c")
    add_deps("adder")
    add_packages("lua")
]], recudo_lua))

            local xmake_opt = {curdir = root}
            os.execv("xmake", {"f", "-c", "-y", "-m", "release"}, xmake_opt)
            os.execv("xmake", {"build", "test_runner"}, xmake_opt)
            local out = os.iorunv("xmake", {"run", "test_runner"}, xmake_opt)
            T.assert_true(out:find("E2E SUCCESS: sum=42 msg=Hello, World!", 1, true) ~= nil, out)
            os.tryrm(root)
        end
    })

    return tests
end
