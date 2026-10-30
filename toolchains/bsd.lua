-- Projectum Lunare Forge
-- Toolchains: FreeBSD, OpenBSD, NetBSD and DragonFly BSD
-- One loader. The spec table keeps the per-OS differences.

local clang_first = {
    cc = {"clang", "gcc", "cc"},
    cxx = {"clang++", "g++", "c++"}
}

local gcc_first = {
    cc = {"gcc", "clang", "cc"},
    cxx = {"g++", "clang++", "c++"}
}

local specs = {
    {
        name = "freebsd",
        homepage = "https://www.freebsd.org/",
        description = "FreeBSD Native & Cross-Compilation SDK Toolchain",
        hosts = {"freebsd"},
        plat = "freebsd",
        sdk_name = "freebsd-sdk",
        sdk_env = "FREEBSD_SDK",
        sysroot_env = "FREEBSD_SYSROOT",
        sysroot_usr = true,
        clang_target = "-unknown-freebsd",
        native_cc = clang_first.cc,
        native_cxx = clang_first.cxx
    },
    {
        name = "openbsd",
        homepage = "https://www.openbsd.org/",
        description = "OpenBSD Native & Cross-Compilation SDK Toolchain",
        hosts = {"openbsd"},
        plat = "openbsd",
        sdk_name = "openbsd-sdk",
        sdk_env = "OPENBSD_SDK",
        sysroot_env = "OPENBSD_SYSROOT",
        sysroot_usr = true,
        clang_target = "-unknown-openbsd",
        native_cc = clang_first.cc,
        native_cxx = clang_first.cxx
    },
    {
        -- No Clang fallback. NETBSD_TOOLDIR is the tool directory.
        -- A missing binary still uses <triple>-netbsd- when that directory exists.
        -- Sysroot is NETBSD_SYSROOT or <sdk>/sysroot.
        name = "netbsd",
        homepage = "https://www.netbsd.org/",
        description = "NetBSD Native & Cross-Compilation SDK Toolchain",
        hosts = {"netbsd"},
        plat = "netbsd",
        sdk_name = "netbsd-sdk",
        sdk_env = "NETBSD_SDK",
        tooldir_env = "NETBSD_TOOLDIR",
        synthetic_suffix = "-netbsd-",
        sysroot_env = "NETBSD_SYSROOT",
        native_cc = gcc_first.cc,
        native_cxx = gcc_first.cxx
    },
    {
        name = "dragonflybsd",
        homepage = "https://www.dragonflybsd.org/",
        description = "DragonFly BSD Native & Cross-Compilation SDK Toolchain",
        hosts = {"dragonflybsd", "dragonfly"},
        plat = "dragonflybsd",
        sdk_name = "dragonflybsd-sdk",
        sdk_env = "DRAGONFLY_SDK",
        sysroot_env = "DRAGONFLY_SYSROOT",
        sysroot_usr = true,
        clang_target = "-unknown-dragonfly",
        native_cc = gcc_first.cc,
        native_cxx = gcc_first.cxx
    }
}

local function host_matches(spec)
    local host = os.host()
    for _, name in ipairs(spec.hosts) do
        if host == name then
            return true
        end
    end
    return false
end

local function first_tool(find_tool, names)
    for _, name in ipairs(names) do
        local tool = find_tool(name)
        if tool then
            return tool
        end
    end
end

local function set_native_tools(toolchain, spec, find_tool)
    local cc = first_tool(find_tool, spec.native_cc)
    local cxx = first_tool(find_tool, spec.native_cxx)
    if cc then toolchain:set("toolset", "cc", cc.program) end
    if cxx then toolchain:set("toolset", "cxx", cxx.program) end
    toolchain:set("toolset", "ld", (cxx or cc or {program = "ld"}).program)
    toolchain:set("toolset", "ar", "ar")
    toolchain:set("toolset", "as", "as")
    toolchain:set("toolset", "ranlib", "ranlib")
end

local function set_prefixed_tools(toolchain, prefix, bindir)
    local names = {
        cc = prefix .. "gcc",
        cxx = prefix .. "g++",
        ld = prefix .. "gcc",
        ar = prefix .. "ar",
        as = prefix .. "as",
        ranlib = prefix .. "ranlib"
    }
    for _, kind in ipairs({"cc", "cxx", "ld", "ar", "as", "ranlib"}) do
        local program = bindir and path.join(bindir, names[kind]) or names[kind]
        toolchain:set("toolset", kind, program)
    end
    if bindir then
        toolchain:add("envs", "PATH", bindir)
    end
end

local function define(spec)
    toolchain(spec.name, function ()
        set_kind("standalone")
        set_homepage(spec.homepage)
        set_description(spec.description)

        on_check(function (toolchain)
            -- xmake sets os.scriptdir() to toolchains/ for this callback.
            local root = path.join(os.scriptdir(), "..")
            import("modules.detect.bsd", {rootdir = root})
            import("modules.sdk", {rootdir = root})
            local arch = bsd.normalize_arch(toolchain:arch())
            if host_matches(spec) and arch == bsd.normalize_arch(os.arch(), spec.plat) then
                return true
            end
            if bsd.is_available(spec.plat, arch) then
                return true
            end
            return sdk.exists(spec.sdk_name, spec.sdk_env)
        end)

        on_load(function (toolchain)
            local root = path.join(os.scriptdir(), "..")
            import("modules.detect.bsd", {rootdir = root})
            import("lib.detect.find_tool")
            local arch = bsd.normalize_arch(toolchain:arch())
            local triple_arch = bsd.get_triple_arch(spec.plat, arch)

            if host_matches(spec) and arch == bsd.normalize_arch(os.arch(), spec.plat) then
                set_native_tools(toolchain, spec, find_tool)
                return
            end

            import("modules.sdk", {rootdir = root})
            local sdkdir = (spec.tooldir_env and os.getenv(spec.tooldir_env)) or sdk.find(spec.sdk_name, spec.sdk_env)
            local bindir = sdkdir and path.join(sdkdir, "bin")

            local found_prefix = bsd.find_toolchain(spec.plat, arch, {bindir = bindir})
            if not found_prefix and bindir and spec.synthetic_suffix then
                found_prefix = triple_arch .. spec.synthetic_suffix
            end

            if found_prefix then
                set_prefixed_tools(toolchain, found_prefix, bindir)
            elseif spec.clang_target then
                local clang = first_tool(find_tool, {"clang"})
                if clang then
                    toolchain:set("toolset", "cc", clang.program)
                    local clangxx = first_tool(find_tool, {"clang++"})
                    if clangxx then toolchain:set("toolset", "cxx", clangxx.program) end
                    toolchain:set("toolset", "ld", (clangxx or clang).program)
                    local target = triple_arch .. spec.clang_target
                    toolchain:add("cxflags", "--target=" .. target)
                    toolchain:add("ldflags", "--target=" .. target)
                end
            end

            local sysroot = os.getenv(spec.sysroot_env) or (sdkdir and path.join(sdkdir, "sysroot")) or (spec.sysroot_usr and sdkdir and os.isdir(path.join(sdkdir, "usr")) and sdkdir)
            if sysroot and os.isdir(sysroot) then
                toolchain:add("cxflags", "--sysroot=" .. sysroot)
                toolchain:add("ldflags", "--sysroot=" .. sysroot)
            end
        end)
    end)
end

for _, spec in ipairs(specs) do
    define(spec)
end
