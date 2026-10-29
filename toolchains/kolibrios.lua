-- Projectum Lunare Forge
-- Toolchain: KolibriOS x86 (kos32-gcc)
-- Reference: dotstar/scripts/tools/kolibrios-sdk.lua and solo/mk/kolibri.mk

toolchain("kolibrios")
    set_kind("standalone")
    set_homepage("https://kolibrios.org/")
    set_description("KolibriOS 32-bit x86 GCC Cross-Compiler SDK")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists("kolibrios-sdk", "KOLIBRI_SDK")
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find("kolibrios-sdk", "KOLIBRI_SDK")
        local bindir = path.join(sdkdir, "bin")

        toolchain:set("toolset", "cc", path.join(bindir, "kos32-gcc"))
        toolchain:set("toolset", "cxx", path.join(bindir, "kos32-g++"))
        toolchain:set("toolset", "ld", path.join(bindir, "kos32-ld"))
        toolchain:set("toolset", "ar", path.join(bindir, "kos32-ar"))
        toolchain:set("toolset", "as", path.join(bindir, "kos32-as"))

        toolchain:add("envs", "PATH", bindir)
        toolchain:add("cxflags", "-std=gnu89", "-nostdlib", "-U_WIN32", "-D__KOLIBRIOS__", "-I" .. path.join(sdkdir, "include"), {force = true})
    end)
