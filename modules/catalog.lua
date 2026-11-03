-- Projectum Lunare Recudo
-- One list for platforms, default architectures, static linking and the recudo CLI.
--
-- Project and platform scripts include this file: import() is not available
-- while those scripts are loading. A module import sees the functions below.
-- An include must call _dismiss() before returning to the project script so the
-- helpers do not replace names the project already defined.

local previous = {
    get = get,
    default_archs = default_archs,
    is_static = is_static,
    is_bsd = is_bsd,
    same_os = same_os,
    cli_order = cli_order,
    aliases = aliases,
    cli_targets = cli_targets,
    gcc_toolchains = gcc_toolchains,
    _dismiss = _dismiss
}

local BASE_HOSTS = {"linux", "windows", "macosx", "bsd"}

local function host_list(extra)
    local hosts = {}
    for _, name in ipairs(BASE_HOSTS) do
        table.insert(hosts, name)
    end
    for _, name in ipairs(extra or {}) do
        table.insert(hosts, name)
    end
    return hosts
end

local function vintage_formats(binary)
    return {
        {"static", "lib$(name).a"},
        {"object", "$(name).o"},
        {"binary", binary}
    }
end

local function bsd_formats()
    return {
        {"static", "lib$(name).a"},
        {"object", "$(name).o"},
        {"shared", "lib$(name).so"},
        {"symbol", "$(name).sym"}
    }
end

local platforms = {
    {
        id = "amiga",
        name = "AmigaOS Classic (m68k)",
        os = "amigaos",
        arch = "m68k",
        archs = {"m68k", "m68000", "m68020", "m68030", "m68040", "m68060"},
        hosts = host_list(),
        toolchain = "amigaos",
        sdk_name = "amigaos-gcc",
        sdk_env = "AMIGAOS_GCC",
        sdk_alt = {name = "amigaos-sdk", env = "AMIGA_SDK"},
        check_file = "bin/m68k-amigaos-gcc",
        formats = vintage_formats("$(name)"),
        static_only = true,
        probe = "sdk",
        gcc = {
            homepage = "https://github.com/AmigaPorts/m68k-amigaos-gcc",
            description = "AmigaOS Classic m68k GCC Cross-Compiler SDK",
            prefix = "m68k-amigaos-",
            tail_flags = {"-msoft-float", "-noixemul"}
        }
    },
    {
        id = "atari",
        name = "Atari ST/STE/TT/Falcon (m68k)",
        os = "atarist",
        arch = "m68k",
        archs = {"m68k", "m68000", "m68020", "m68030", "m68040", "m68060"},
        hosts = host_list(),
        toolchain = "atarist",
        -- two real toolchains exist for this target: the modern mintelf (ELF
        -- objects, PRG/ELF output, GDB, C++13) and the classic mint (a.out,
        -- TOS, MonST2 symbols). Mintelf is the default; set ATARIST_SDK to a
        -- classic install to use that instead.
        sdk_name = "atarist-mintelf",
        sdk_env = "ATARIST_MINTELF",
        sdk_alt = {name = "atarist-mint", env = "ATARIST_SDK"},
        check_file = "bin/m68k-atari-mintelf-gcc",
        formats = vintage_formats("$(name).tos"),
        static_only = true,
        probe = "sdk",
        gcc = {
            homepage = "http://vincent.riviere.free.fr/soft/m68k-atari-mint/",
            description = "Atari ST m68k FreeMiNT GCC Cross-Compiler SDK",
            prefix = "m68k-atari-mintelf-",
            tail_flags = {"-msoft-float"}
        }
    },
    {
        id = "kolibri",
        name = "KolibriOS 32-bit (x86)",
        os = "kolibrios",
        arch = "i386",
        archs = {"i386"},
        hosts = host_list(),
        toolchain = "kolibrios",
        sdk_name = "kolibrios-sdk",
        sdk_env = "KOLIBRI_SDK",
        check_file = "bin/kos32-gcc",
        formats = vintage_formats("$(name)"),
        static_only = true,
        probe = "sdk"
    },
    {
        id = "dos",
        name = "MS-DOS 32-bit Protected Mode (Watcom)",
        os = "dos",
        arch = "i386",
        archs = {"i386"},
        hosts = host_list(),
        toolchain = "watcom",
        sdk_name = "watcom",
        sdk_env = "WATCOM",
        formats = vintage_formats("$(name).exe"),
        static_only = true,
        probe = "watcom"
    },
    {
        id = "os2",
        name = "IBM OS/2 Warp 32-bit (Watcom)",
        os = "os2",
        arch = "i386",
        archs = {"i386"},
        hosts = host_list(),
        toolchain = "watcom",
        sdk_name = "watcom",
        sdk_env = "WATCOM",
        formats = vintage_formats("$(name).exe"),
        static_only = true,
        probe = "watcom"
    },
    {
        id = "wince",
        name = "Microsoft Windows CE (eVC 3.0)",
        os = "windows_ce",
        arch = "arm",
        archs = {"arm", "mips", "ppc", "sh3", "sh4", "x86"},
        hosts = host_list(),
        toolchain = "evc3",
        sdk_name = "evc3",
        sdk_env = "EVC3_DIR",
        formats = vintage_formats("$(name).exe"),
        static_only = true,
        probe = "evc3"
    },
    {
        -- https://www.freebsd.org/where/
        id = "freebsd",
        name = "FreeBSD",
        os = "freebsd",
        arch = "x86_64",
        archs = {
            "x86_64", "i386", "arm64", "armv7",
            "ppc", "ppc64", "ppc64le", "ppcspe", "riscv64"
        },
        hosts = host_list({"freebsd"}),
        toolchain = "freebsd",
        sdk_name = "freebsd-sdk",
        sdk_env = "FREEBSD_SDK",
        formats = bsd_formats(),
        installdir = "/usr/local",
        probe = "bsd"
    },
    {
        -- https://www.openbsd.org/faq/faq4.html#Download
        id = "openbsd",
        name = "OpenBSD",
        os = "openbsd",
        arch = "x86_64",
        archs = {
            "x86_64", "i386", "arm64", "armv7",
            "alpha", "hppa", "m88k", "mips64",
            "ppc", "ppc64", "riscv64", "sh4", "sparc64"
        },
        hosts = host_list({"openbsd"}),
        toolchain = "openbsd",
        sdk_name = "openbsd-sdk",
        sdk_env = "OPENBSD_SDK",
        formats = bsd_formats(),
        installdir = "/usr/local",
        probe = "bsd"
    },
    {
        -- https://wiki.netbsd.org/ports/
        id = "netbsd",
        name = "NetBSD",
        os = "netbsd",
        arch = "x86_64",
        archs = {
            "x86_64", "i386", "arm", "arm64",
            "alpha", "hppa", "ia64", "m68k", "m68010",
            "mips", "mips64", "mipseb", "mipsel",
            "ppc", "ppc64", "riscv32", "riscv64",
            "sh3", "sh3eb", "sh3el",
            "sparc", "sparc64", "vax"
        },
        hosts = host_list({"netbsd"}),
        toolchain = "netbsd",
        sdk_name = "netbsd-sdk",
        sdk_env = "NETBSD_SDK",
        formats = bsd_formats(),
        installdir = "/usr/pkg",
        probe = "bsd"
    },
    {
        -- https://www.dragonflybsd.org/download/
        -- alias is the second platform name, the default-arch key and the host spelling.
        id = "dragonflybsd",
        name = "DragonFly BSD",
        os = "dragonfly",
        arch = "x86_64",
        archs = {"x86_64"},
        hosts = host_list({"dragonflybsd", "dragonfly"}),
        toolchain = "dragonflybsd",
        sdk_name = "dragonflybsd-sdk",
        sdk_env = "DRAGONFLY_SDK",
        formats = bsd_formats(),
        installdir = "/usr/local",
        alias = "dragonfly",
        probe = "bsd"
    }
}

-- Cannot dlopen, but not a platform directory in this addon.
local extra_static = {
    wasm = true
}

local cli_ids = {
    "amiga", "atari", "kolibri", "dos", "os2", "wince",
    "freebsd", "openbsd", "netbsd", "dragonflybsd",
    "posix"
}

local cli_aliases = {
    atarist = "atari",
    amigaos = "amiga",
    kolibrios = "kolibri",
    linux = "posix"
}

local by_id = {}
for _, entry in ipairs(platforms) do
    by_id[entry.id] = entry
end

function get(id)
    return by_id[id]
end

function default_archs()
    local archs = {}
    for _, entry in ipairs(platforms) do
        table.insert(archs, entry.id .. "|" .. entry.arch)
        if entry.alias then
            table.insert(archs, entry.alias .. "|" .. entry.arch)
        end
    end
    return archs
end

function is_static(plat)
    if not plat then
        return false
    end
    if extra_static[plat] then
        return true
    end
    local entry = by_id[plat]
    return entry ~= nil and entry.static_only == true
end

function is_bsd(id)
    local entry = by_id[id]
    return entry ~= nil and entry.probe == "bsd"
end

function same_os(plat, host)
    if not plat or not host then
        return false
    end
    if plat == host then
        return true
    end
    local left = by_id[plat]
    local right = by_id[host]
    if left and left.alias == host then
        return true
    end
    if right and right.alias == plat then
        return true
    end
    return false
end

function cli_order()
    return cli_ids
end

function aliases()
    return cli_aliases
end

function cli_targets()
    local map = {}
    for _, entry in ipairs(platforms) do
        map[entry.id] = {
            id = entry.id,
            name = entry.name,
            plat = entry.id,
            arch = entry.arch,
            toolchain = entry.toolchain,
            sdk_name = entry.sdk_name,
            sdk_env = entry.sdk_env,
            check_file = entry.check_file,
            probe = entry.probe
        }
    end
    map.posix = {
        id = "posix",
        name = string.format("POSIX Host (%s / %s)", os.host(), os.arch()),
        plat = os.host(),
        arch = os.arch(),
        probe = "posix"
    }
    return map
end

function gcc_toolchains()
    local list = {}
    for _, entry in ipairs(platforms) do
        if entry.gcc then
            table.insert(list, {
                name = entry.toolchain,
                homepage = entry.gcc.homepage,
                description = entry.gcc.description,
                prefix = entry.gcc.prefix,
                tail_flags = entry.gcc.tail_flags,
                sdk_name = entry.sdk_name,
                sdk_env = entry.sdk_env,
                check_file = entry.check_file
            })
        end
    end
    return list
end

function _dismiss()
    get = previous.get
    default_archs = previous.default_archs
    is_static = previous.is_static
    is_bsd = previous.is_bsd
    same_os = previous.same_os
    cli_order = previous.cli_order
    aliases = previous.aliases
    cli_targets = previous.cli_targets
    gcc_toolchains = previous.gcc_toolchains
    _dismiss = previous._dismiss
end
