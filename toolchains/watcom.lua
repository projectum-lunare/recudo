-- Projectum Lunare Forge
-- Toolchain: Open Watcom v2 (DOS 32-bit Protected Mode & OS/2 Warp)
-- Uses native Xmake rule: forge.watcom

toolchain("watcom")
    set_kind("standalone")
    set_homepage("https://github.com/open-watcom/open-watcom-v2")
    set_description("Open Watcom v2 C/C++ Cross-Compiler (DOS 32-bit & OS/2)")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        return sdk.exists("watcom", "WATCOM", {fallbacks = "C:\\WATCOM"})
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find("watcom", "WATCOM", {fallbacks = "C:\\WATCOM"})
        local bindir = path.join(sdkdir, "binl64")
        if not os.isdir(bindir) then bindir = path.join(sdkdir, "binl") end
        if not os.isdir(bindir) then bindir = path.join(sdkdir, "binnt64") end
        if not os.isdir(bindir) then bindir = path.join(sdkdir, "binnt") end

        local pathes = {bindir}
        local binw = path.join(sdkdir, "binw")
        if os.isdir(binw) then table.insert(pathes, binw) end
        local binp = path.join(sdkdir, "binp")
        if os.isdir(binp) then table.insert(pathes, binp) end

        toolchain:add("envs", "WATCOM", sdkdir)
        toolchain:add("envs", "EDPATH", path.join(sdkdir, "eddat"))
        for _, p in ipairs(pathes) do
            toolchain:add("envs", "PATH", p)
        end
    end)
