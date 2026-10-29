-- solo - Physical I/O, System Foundations & Hardware Abstractions
-- Toolchain: Atari ST m68k (m68k-atari-mint-gcc)
-- Reference: dotstar/scripts/tools/atarist-sdk.lua and solo/mk/atarist.mk

toolchain("atarist")
    set_kind("standalone")
    set_homepage("http://vincent.riviere.free.fr/soft/m68k-atari-mint/")
    set_description("Atari ST m68k FreeMiNT GCC Cross-Compiler SDK")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists("atarist-sdk", "ATARIST_SDK")
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find("atarist-sdk", "ATARIST_SDK")
        local bindir = path.join(sdkdir, "bin")

        toolchain:set("toolset", "cc", path.join(bindir, "m68k-atari-mint-gcc"))
        toolchain:set("toolset", "cxx", path.join(bindir, "m68k-atari-mint-g++"))
        toolchain:set("toolset", "ld", path.join(bindir, "m68k-atari-mint-gcc"))
        toolchain:set("toolset", "ar", path.join(bindir, "m68k-atari-mint-ar"))
        toolchain:set("toolset", "as", path.join(bindir, "m68k-atari-mint-as"))
        toolchain:set("toolset", "ranlib", path.join(bindir, "m68k-atari-mint-ranlib"))

        toolchain:add("envs", "PATH", bindir)
        toolchain:add("cxflags", "-std=gnu89", "-m68000", "-msoft-float", {force = true})
    end)
