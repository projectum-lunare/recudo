-- Projectum Lunare Forge
-- Toolchain: Atari ST m68k (m68k-atari-mint-gcc)
-- Reference: dotstar/scripts/tools/atarist-sdk.lua and solo/mk/atarist.mk

toolchain("atarist")
    set_kind("standalone")
    set_homepage("http://vincent.riviere.free.fr/soft/m68k-atari-mint/")
    set_description("Atari ST m68k FreeMiNT GCC Cross-Compiler SDK")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists("atarist-sdk", "ATARIST_SDK", {check_file = "bin/m68k-atari-mint-gcc"})
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

        local arch = toolchain:arch() or get_config("arch") or "m68k"
        local cpu_flag = "-m68000"
        if arch == "m68020" or arch == "68020" then
            cpu_flag = "-m68020"
        elseif arch == "m68030" or arch == "68030" then
            cpu_flag = "-m68030"
        elseif arch == "m68040" or arch == "68040" then
            cpu_flag = "-m68040"
        elseif arch == "m68060" or arch == "68060" then
            cpu_flag = "-m68060"
        elseif arch == "m68020-40" then
            cpu_flag = "-m68020-40"
        elseif arch == "m68020-60" then
            cpu_flag = "-m68020-60"
        end

        toolchain:add("cxflags", "-std=gnu89", cpu_flag, "-msoft-float")
    end)
