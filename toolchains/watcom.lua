-- Projectum Lunare Recudo
-- Toolchain: Open Watcom v2 (DOS 32-bit Protected Mode & OS/2 Warp)
-- Uses native Xmake rule: recudo.watcom
-- DOS and OS/2 share this SDK. The catalog records it on both platforms.

includes(path.join(os.scriptdir(), "../modules/catalog.lua"))
local dos = get("dos")
local sdk_name = dos.sdk_name
local sdk_env = dos.sdk_env
_dismiss()

toolchain("watcom")
    set_kind("standalone")
    set_homepage("https://github.com/open-watcom/open-watcom-v2")
    set_description("Open Watcom v2 C/C++ Cross-Compiler (DOS 32-bit & OS/2)")

    on_check(function (toolchain)
        import("modules.detect.watcom", {rootdir = path.join(os.scriptdir(), "..")})
        return watcom.is_available(sdk_env, {sdk_name = sdk_name})
    end)

    on_load(function (toolchain)
        import("modules.detect.watcom", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = watcom.find_sdk(sdk_env, {sdk_name = sdk_name})
        if not sdkdir then return end

        local pathes = watcom.find_tool_paths(sdkdir)
        toolchain:add("envs", sdk_env, sdkdir)
        toolchain:add("envs", "EDPATH", path.join(sdkdir, "eddat"))
        for _, p in ipairs(pathes) do
            toolchain:add("envs", "PATH", p)
        end
    end)
