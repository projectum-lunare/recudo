-- Unit Tests: Toolchains (AmigaOS & Atari ST)

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "amigaos toolchain does not use {force = true} on cxflags",
        func = function ()
            local content = io.readfile("toolchains/amigaos.lua")
            T.assert_not_nil(content)
            T.assert_false(content:find('{force%s*=%s*true}') ~= nil, "AmigaOS toolchain should NOT force cxflags")
        end
    })

    table.insert(tests, {
        name = "atarist toolchain does not use {force = true} on cxflags",
        func = function ()
            local content = io.readfile("toolchains/atarist.lua")
            T.assert_not_nil(content)
            T.assert_false(content:find('{force%s*=%s*true}') ~= nil, "Atari ST toolchain should NOT force cxflags")
        end
    })

    table.insert(tests, {
        name = "amigaos toolchain supports 68000 through 68060 CPU mapping",
        func = function ()
            local content = io.readfile("toolchains/amigaos.lua")
            T.assert_true(content:find('-m68000') ~= nil, "Should support -m68000")
            T.assert_true(content:find('-m68020') ~= nil, "Should support -m68020")
            T.assert_true(content:find('-m68030') ~= nil, "Should support -m68030")
            T.assert_true(content:find('-m68040') ~= nil, "Should support -m68040")
            T.assert_true(content:find('-m68060') ~= nil, "Should support -m68060")
        end
    })

    table.insert(tests, {
        name = "atarist toolchain supports 68000 through 68060 CPU mapping",
        func = function ()
            local content = io.readfile("toolchains/atarist.lua")
            T.assert_true(content:find('-m68000') ~= nil, "Should support -m68000")
            T.assert_true(content:find('-m68020') ~= nil, "Should support -m68020")
            T.assert_true(content:find('-m68030') ~= nil, "Should support -m68030")
            T.assert_true(content:find('-m68040') ~= nil, "Should support -m68040")
            T.assert_true(content:find('-m68060') ~= nil, "Should support -m68060")
        end
    })

    table.insert(tests, {
        name = "amiga and atari platform files register expanded archs",
        func = function ()
            local amiga_plat = io.readfile("platforms/amiga/xmake.lua")
            local atari_plat = io.readfile("platforms/atari/xmake.lua")
            T.assert_true(amiga_plat:find('m68020') ~= nil, "Amiga platform should declare m68020")
            T.assert_true(atari_plat:find('m68020') ~= nil, "Atari platform should declare m68020")
        end
    })

    return tests
end
