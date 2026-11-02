-- Unit Tests: Teal Language Rule (recudo.teal)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "teal rule files exist and define expected rule names and extensions",
        func = function ()
            local content_xmake = io.readfile(path.join(os.projectdir(), "rules/lang/teal/xmake.lua"))
            T.assert_not_nil(content_xmake)
            T.assert_true(content_xmake:find('setup_teal_rule%("recudo%.lang%.teal"%)') ~= nil)
            T.assert_true(content_xmake:find('set_extensions%("%.tl"%)') ~= nil)
        end
    })

    table.insert(tests, {
        name = "tl compiler verifies valid typed code and type mismatch detection",
        func = function ()
            -- Locate installed tl
            local xmake_pkg_tl = path.join(os.getenv("HOME") or "", ".xmake/packages/t/tl")
            local tl_bin
            if os.isdir(xmake_pkg_tl) then
                local matches = os.files(path.join(xmake_pkg_tl, "**/bin/tl"))
                if matches and #matches > 0 then
                    tl_bin = matches[1]
                end
            end
            if not tl_bin or not os.isexec(tl_bin) then
                import("lib.detect.find_tool")
                local tool = find_tool("tl")
                tl_bin = tool and tool.program
            end

            if not tl_bin or not os.isexec(tl_bin) then
                return
            end

            local tmpdir = path.join(os.tmpdir(), "recudo_test_teal")
            os.mkdir(tmpdir)

            -- 1. Valid typed code
            local valid_tl = path.join(tmpdir, "valid.tl")
            local valid_lua = path.join(tmpdir, "valid.lua")
            io.writefile(valid_tl, [[
                local record Point
                    x: number
                    y: number
                end
                local function add(p1: Point, p2: Point): Point
                    return {x = p1.x + p2.x, y = p1.y + p2.y}
                end
                local p: Point = add({x = 10, y = 20}, {x = 30, y = 40})
                print(p.x, p.y)
            ]])

            local ok_valid = try {
                function ()
                    os.vrunv(tl_bin, {"gen", "-c", "-o", valid_lua, valid_tl})
                    return true
                end
            }
            T.assert_true(ok_valid == true, "tl gen should succeed for valid typed Teal code")
            T.assert_true(os.isfile(valid_lua), "transpiled valid.lua should exist")
            local lua_content = io.readfile(valid_lua)
            T.assert_true(lua_content:find("Point = {}", 1, true) ~= nil or lua_content:find("function add(", 1, true) ~= nil)

            -- 2. Invalid code with type error
            local invalid_tl = path.join(tmpdir, "invalid.tl")
            local invalid_lua = path.join(tmpdir, "invalid.lua")
            io.writefile(invalid_tl, [[
                local x: number = "this is a string, not a number"
            ]])

            local ok_invalid = try {
                function ()
                    os.vrunv(tl_bin, {"gen", "-c", "-o", invalid_lua, invalid_tl})
                    return true
                end
            }
            T.assert_true(ok_invalid ~= true, "tl gen with -c should fail when type mismatch is present")

            -- Cleanup
            os.rm(tmpdir)
        end
    })

    return tests
end
