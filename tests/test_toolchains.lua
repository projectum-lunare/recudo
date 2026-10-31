-- Unit Tests: m68k toolchains and the shared platform catalog

import("catalog", {rootdir = "modules"})
import("core.platform.platform")

local function listed(values, item)
    for _, value in ipairs(table.wrap(values)) do
        if value == item then
            return true
        end
    end
    return false
end

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "m68k toolchain loader does not force cxflags",
        func = function ()
            local content = io.readfile("toolchains/m68k.lua")
            T.assert_not_nil(content)
            T.assert_false(content:find('{force%s*=%s*true}') ~= nil, "m68k toolchain should NOT force cxflags")
        end
    })

    table.insert(tests, {
        name = "m68k toolchain maps 68000 through 68060",
        func = function ()
            local content = io.readfile("toolchains/m68k.lua")
            T.assert_true(content:find('-m68000') ~= nil, "Should support -m68000")
            T.assert_true(content:find('-m68020') ~= nil, "Should support -m68020")
            T.assert_true(content:find('-m68030') ~= nil, "Should support -m68030")
            T.assert_true(content:find('-m68040') ~= nil, "Should support -m68040")
            T.assert_true(content:find('-m68060') ~= nil, "Should support -m68060")
            T.assert_true(content:find('-m68020%-40') ~= nil, "Should support -m68020-40")
            T.assert_true(content:find('-m68020%-60') ~= nil, "Should support -m68020-60")
        end
    })

    table.insert(tests, {
        name = "catalog keeps amiga and atari gcc prefixes apart",
        func = function ()
            local amiga = catalog.get("amiga")
            local atari = catalog.get("atari")
            T.assert_equal(amiga.gcc.prefix, "m68k-amigaos-")
            T.assert_equal(atari.gcc.prefix, "m68k-atari-mint-")
            T.assert_contains(amiga.gcc.tail_flags, "-noixemul")
            T.assert_false(listed(atari.gcc.tail_flags, "-noixemul"))
            T.assert_contains(amiga.archs, "m68020")
            T.assert_contains(atari.archs, "m68020")
        end
    })

    table.insert(tests, {
        name = "catalog default archs and static link policy",
        func = function ()
            local archs = catalog.default_archs()
            T.assert_contains(archs, "amiga|m68k")
            T.assert_contains(archs, "wince|arm")
            T.assert_contains(archs, "dragonflybsd|x86_64")
            T.assert_contains(archs, "dragonfly|x86_64")
            T.assert_true(catalog.is_static("dos"))
            T.assert_true(catalog.is_static("wasm"))
            T.assert_false(catalog.is_static("freebsd"))
            T.assert_false(catalog.is_static("linux"))
            T.assert_false(catalog.is_static(nil))
            T.assert_true(catalog.same_os("dragonfly", "dragonflybsd"))
            T.assert_true(catalog.same_os("dragonflybsd", "dragonfly"))
            T.assert_false(catalog.same_os("freebsd", "openbsd"))
        end
    })

    table.insert(tests, {
        name = "platform scripts register the catalog entry xmake can load",
        func = function ()
            local ids = {
                "amiga", "atari", "kolibri", "dos", "os2", "wince",
                "freebsd", "openbsd", "netbsd", "dragonflybsd"
            }
            for _, id in ipairs(ids) do
                local content = io.readfile(path.join("platforms", id, "xmake.lua"))
                T.assert_true(content:find('define_platform%("' .. id .. '"%)') ~= nil, id .. " script should call define_platform")
                local entry = catalog.get(id)
                T.assert_not_nil(entry, id)
                local instance = platform.load(id, entry.arch)
                T.assert_equal(instance:os(), entry.os, id)
                T.assert_true(listed(instance:archs(), entry.arch), id .. " should list its default arch")
                local toolchain = instance:get("toolchains")
                T.assert_true(toolchain == entry.toolchain or listed(toolchain, entry.toolchain), id .. " toolchain")
                local formats = instance:get("formats")
                for _, fmt in ipairs(entry.formats) do
                    T.assert_equal(formats[fmt[1]], fmt[2], id .. " " .. fmt[1] .. " format")
                end
                if entry.installdir then
                    T.assert_equal(instance:get("installdir"), entry.installdir, id .. " installdir")
                end
            end
            local freebsd = platform.load("freebsd", "x86_64")
            T.assert_equal(freebsd:get("formats").shared, "lib$(name).so")
            local netbsd = platform.load("netbsd", "x86_64")
            T.assert_equal(netbsd:get("installdir"), "/usr/pkg")
            T.assert_true(listed(netbsd:archs(), "vax"))
            T.assert_equal(platform.load("dragonflybsd", "x86_64"):os(), "dragonfly")
            local dragonfly = platform.load("dragonfly", "x86_64")
            T.assert_equal(dragonfly:os(), "dragonfly")
            T.assert_equal(dragonfly:get("toolchains"), "dragonflybsd")
        end
    })

    table.insert(tests, {
        name = "toolchain scripts take SDK identity from the catalog",
        func = function ()
            local function uses_catalog(file, hardcoded)
                local content = io.readfile(file)
                T.assert_not_nil(content, file)
                T.assert_true(content:find("catalog.lua", 1, true) ~= nil, file .. " should include the catalog")
                for _, word in ipairs(hardcoded) do
                    T.assert_true(content:find(word, 1, true) == nil, file .. " still hardcodes " .. word)
                end
            end
            uses_catalog("toolchains/bsd.lua", {
                "freebsd-sdk", "FREEBSD_SDK",
                "openbsd-sdk", "OPENBSD_SDK",
                "netbsd-sdk", "NETBSD_SDK",
                "dragonflybsd-sdk", "DRAGONFLY_SDK"
            })
            uses_catalog("toolchains/kolibrios.lua", {"\"kolibrios-sdk\"", "\"KOLIBRI_SDK\"", "\"bin/kos32-gcc\""})
            uses_catalog("toolchains/watcom.lua", {"is_available(\"WATCOM\")", "find_sdk(\"WATCOM\""})
            uses_catalog("toolchains/evc3.lua", {"EVC3_DIR"})
            T.assert_equal(catalog.get("freebsd").sdk_env, "FREEBSD_SDK")
            T.assert_equal(catalog.get("kolibri").check_file, "bin/kos32-gcc")
            T.assert_equal(catalog.get("dos").sdk_name, "watcom")
            T.assert_equal(catalog.get("wince").sdk_env, "EVC3_DIR")
        end
    })

    return tests
end
