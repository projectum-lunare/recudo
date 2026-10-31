-- Projectum Lunare Forge
-- Toolchain: KolibriOS x86 (kos32-gcc)
-- Reference: dotstar/scripts/tools/kolibrios-sdk.lua and solo/mk/kolibri.mk

includes(path.join(os.scriptdir(), "../modules/catalog.lua"))
local kolibri = get("kolibri")
local sdk_name = kolibri.sdk_name
local sdk_env = kolibri.sdk_env
local check_file = kolibri.check_file
_dismiss()

toolchain("kolibrios")
    set_kind("standalone")
    set_homepage("https://kolibrios.org/")
    set_description("KolibriOS 32-bit x86 GCC Cross-Compiler SDK")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists(sdk_name, sdk_env, {check_file = check_file})
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find(sdk_name, sdk_env)
        local bindir = path.join(sdkdir, "bin")

        toolchain:set("toolset", "cc", path.join(bindir, "kos32-gcc"))
        toolchain:set("toolset", "cxx", path.join(bindir, "kos32-g++"))
        toolchain:set("toolset", "ld", path.join(bindir, "kos32-ld"))
        toolchain:set("toolset", "ar", path.join(bindir, "kos32-ar"))
        toolchain:set("toolset", "as", path.join(bindir, "kos32-as"))

        toolchain:add("envs", "PATH", bindir)
        toolchain:add("cxflags", "-std=gnu89", "-nostdlib", "-U_WIN32", "-D__KOLIBRIOS__", "-I" .. path.join(sdkdir, "include"), {force = true})
    end)
