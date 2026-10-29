-- Projectum Lunare Forge
-- Toolchain: Open Watcom v2 (DOS 32-bit Protected Mode)
-- Uses native Xmake rule: vintage.watcom

toolchain("watcom")
    set_kind("standalone")
    set_homepage("https://github.com/open-watcom/open-watcom-v2")
    set_description("Open Watcom v2 C/C++ Cross-Compiler (DOS 32-bit)")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists("watcom", "WATCOM", {fallbacks = "C:\\WATCOM"})
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find("watcom", "WATCOM", {fallbacks = "C:\\WATCOM"})
        toolchain:add("envs", "WATCOM", sdkdir)
    end)
