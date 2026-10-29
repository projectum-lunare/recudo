-- Projectum Lunare Forge
-- Toolchain: DragonFly BSD Cross & Native Toolchain
-- Reference: https://www.dragonflybsd.org/download/

toolchain("dragonflybsd")
    set_kind("standalone")
    set_homepage("https://www.dragonflybsd.org/")
    set_description("DragonFly BSD Native & Cross-Compilation SDK Toolchain")

    on_check(function (toolchain)
        if os.host() == "dragonflybsd" or os.host() == "dragonfly" then
            return true
        end
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local find_file = import("lib.detect.find_file")
        local pathes = path.splitenv(os.getenv("PATH") or "")
        if find_file("x86_64-unknown-dragonfly-gcc", pathes) or find_file("x86_64-dragonfly-gcc", pathes) then
            return true
        end
        return sdk.exists("dragonflybsd-sdk", "DRAGONFLY_SDK") or os.getenv("DRAGONFLY_SYSROOT") ~= nil
    end)

    on_load(function (toolchain)
        if os.host() == "dragonflybsd" or os.host() == "dragonfly" then
            local find_tool = import("lib.detect.find_tool")
            local cc = find_tool("gcc") or find_tool("clang") or find_tool("cc")
            local cxx = find_tool("g++") or find_tool("clang++") or find_tool("c++")
            if cc then toolchain:set("toolset", "cc", cc.program) end
            if cxx then toolchain:set("toolset", "cxx", cxx.program) end
            toolchain:set("toolset", "ld", (cxx or cc or {program = "ld"}).program)
            toolchain:set("toolset", "ar", "ar")
            toolchain:set("toolset", "as", "as")
            toolchain:set("toolset", "ranlib", "ranlib")
            return
        end

        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local sdkdir = sdk.find("dragonflybsd-sdk", "DRAGONFLY_SDK")
        local bindir = sdkdir and path.join(sdkdir, "bin")

        local prefixes = {
            "x86_64-unknown-dragonfly-",
            "x86_64-dragonfly-"
        }

        local find_tool = import("lib.detect.find_tool")
        local opt_find = bindir and {pathes = bindir} or {}
        local found_prefix = nil
        for _, pfx in ipairs(prefixes) do
            local t = find_tool(pfx .. "gcc", opt_find) or find_tool(pfx .. "clang", opt_find)
            if t then
                found_prefix = pfx
                break
            end
        end

        if found_prefix then
            local cc_name = found_prefix .. "gcc"
            local cxx_name = found_prefix .. "g++"
            local ld_name = found_prefix .. "gcc"
            local ar_name = found_prefix .. "ar"
            local as_name = found_prefix .. "as"
            local ranlib_name = found_prefix .. "ranlib"

            if bindir then
                toolchain:set("toolset", "cc", path.join(bindir, cc_name))
                toolchain:set("toolset", "cxx", path.join(bindir, cxx_name))
                toolchain:set("toolset", "ld", path.join(bindir, ld_name))
                toolchain:set("toolset", "ar", path.join(bindir, ar_name))
                toolchain:set("toolset", "as", path.join(bindir, as_name))
                toolchain:set("toolset", "ranlib", path.join(bindir, ranlib_name))
                toolchain:add("envs", "PATH", bindir)
            else
                toolchain:set("toolset", "cc", cc_name)
                toolchain:set("toolset", "cxx", cxx_name)
                toolchain:set("toolset", "ld", ld_name)
                toolchain:set("toolset", "ar", ar_name)
                toolchain:set("toolset", "as", as_name)
                toolchain:set("toolset", "ranlib", ranlib_name)
            end
        else
            local clang = find_tool("clang")
            if clang then
                toolchain:set("toolset", "cc", clang.program)
                local clangxx = find_tool("clang++")
                if clangxx then toolchain:set("toolset", "cxx", clangxx.program) end
                toolchain:set("toolset", "ld", (clangxx or clang).program)
                toolchain:add("cxflags", "--target=x86_64-unknown-dragonfly")
                toolchain:add("ldflags", "--target=x86_64-unknown-dragonfly")
            end
        end

        local sysroot = os.getenv("DRAGONFLY_SYSROOT") or (sdkdir and path.join(sdkdir, "sysroot")) or (sdkdir and os.isdir(path.join(sdkdir, "usr")) and sdkdir)
        if sysroot and os.isdir(sysroot) then
            toolchain:add("cxflags", "--sysroot=" .. sysroot)
            toolchain:add("ldflags", "--sysroot=" .. sysroot)
        end
    end)
