-- Projectum Lunare Forge
-- Toolchain: NetBSD Cross & Native Toolchain
-- Reference: https://wiki.netbsd.org/ports/ and NetBSD build.sh tools

toolchain("netbsd")
    set_kind("standalone")
    set_homepage("https://www.netbsd.org/")
    set_description("NetBSD Native & Cross-Compilation SDK Toolchain")

    on_check(function (toolchain)
        if os.host() == "netbsd" then
            return true
        end
        import("modules.detect.bsd", {rootdir = path.join(os.scriptdir(), "..")})
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local arch = bsd.normalize_arch(toolchain:arch())
        if bsd.is_available("netbsd", arch) then
            return true
        end
        return sdk.exists("netbsd-sdk", "NETBSD_SDK")
    end)

    on_load(function (toolchain)
        import("modules.detect.bsd", {rootdir = path.join(os.scriptdir(), "..")})
        local arch = bsd.normalize_arch(toolchain:arch())

        if os.host() == "netbsd" then
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
        local sdkdir = os.getenv("NETBSD_TOOLDIR") or sdk.find("netbsd-sdk", "NETBSD_SDK")
        local bindir = sdkdir and path.join(sdkdir, "bin")

        local found_prefix, found_tool = bsd.find_toolchain("netbsd", arch, {bindir = bindir})
        if not found_prefix and bindir then
            local triple_arch = bsd.get_triple_arch("netbsd", arch)
            found_prefix = triple_arch .. "-netbsd-"
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
        end

        local sysroot = os.getenv("NETBSD_SYSROOT") or (sdkdir and path.join(sdkdir, "sysroot"))
        if sysroot and os.isdir(sysroot) then
            toolchain:add("cxflags", "--sysroot=" .. sysroot)
            toolchain:add("ldflags", "--sysroot=" .. sysroot)
        end
    end)
