-- solo - Physical I/O, System Foundations & Hardware Abstractions
-- Toolchain: AmigaOS m68k (Bebbo GCC)
-- Reference: dotstar/scripts/tools/amigaos-sdk.lua and solo/mk/amiga.mk

toolchain("amigaos")
    set_kind("standalone")
    set_homepage("https://github.com/AmigaPorts/m68k-amigaos-gcc")
    set_description("AmigaOS Classic m68k GCC Cross-Compiler SDK")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists("amigaos-sdk", "AMIGA_SDK")
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find("amigaos-sdk", "AMIGA_SDK")
        local bindir = path.join(sdkdir, "bin")

        toolchain:set("toolset", "cc", path.join(bindir, "m68k-amigaos-gcc"))
        toolchain:set("toolset", "cxx", path.join(bindir, "m68k-amigaos-g++"))
        toolchain:set("toolset", "ld", path.join(bindir, "m68k-amigaos-gcc"))
        toolchain:set("toolset", "ar", path.join(bindir, "m68k-amigaos-ar"))
        toolchain:set("toolset", "as", path.join(bindir, "m68k-amigaos-as"))
        toolchain:set("toolset", "ranlib", path.join(bindir, "m68k-amigaos-ranlib"))

        toolchain:add("envs", "PATH", bindir)
        toolchain:add("cxflags", "-std=gnu89", "-m68000", "-msoft-float", "-noixemul", {force = true})
    end)
