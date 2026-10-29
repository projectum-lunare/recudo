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
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local arch = toolchain:arch() or "x86_64"
        local prefix = arch .. "--netbsd-"
        local elf_prefix = arch .. "--netbsdelf-"
        local find_file = import("lib.detect.find_file")
        local pathes = path.splitenv(os.getenv("PATH") or "")
        if find_file(prefix .. "gcc", pathes) or find_file(elf_prefix .. "gcc", pathes) then
            return true
        end
        return sdk.exists("netbsd-sdk", "NETBSD_SDK") or os.getenv("NETBSD_TOOLDIR") ~= nil
    end)

    on_load(function (toolchain)
        local arch = toolchain:arch() or "x86_64"
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

        local triple_arch = arch
        if arch == "i386" then
            triple_arch = "i486"
        elseif arch == "arm64" then
            triple_arch = "aarch64"
        end

        local prefixes = {
            triple_arch .. "--netbsd-",
            triple_arch .. "--netbsdelf-",
            arch .. "--netbsd-",
            arch .. "--netbsdelf-"
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

        if not found_prefix and bindir then
            found_prefix = prefixes[1]
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
