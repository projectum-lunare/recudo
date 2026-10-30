-- Projectum Lunare Forge
-- Toolchain: Open Watcom v2 (DOS 32-bit Protected Mode & OS/2 Warp)
-- Uses native Xmake rule: forge.watcom

toolchain("watcom")
    set_kind("standalone")
    set_homepage("https://github.com/open-watcom/open-watcom-v2")
    set_description("Open Watcom v2 C/C++ Cross-Compiler (DOS 32-bit & OS/2)")

    on_check(function (toolchain)
        import("modules.detect.watcom", {rootdir = path.join(os.scriptdir(), "..")})
        return watcom.is_available("WATCOM")
    end)

    on_load(function (toolchain)
        import("modules.detect.watcom", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = watcom.find_sdk("WATCOM")
        if not sdkdir then return end

        local pathes = watcom.find_tool_paths(sdkdir)
        toolchain:add("envs", "WATCOM", sdkdir)
        toolchain:add("envs", "EDPATH", path.join(sdkdir, "eddat"))
        for _, p in ipairs(pathes) do
            toolchain:add("envs", "PATH", p)
        end
    end)
