-- Projectum Lunare Forge - Cross-Compilation & Toolchain Engine
-- Reference: https://xmake.io/guide/extensions/addons/introduction.html

import("core.base.option")
import("modules.sdk", {rootdir = path.join(os.scriptdir(), "../..")})

local targets = {
    amiga = {
        id = "amiga",
        name = "AmigaOS Classic (m68k)",
        plat = "amiga",
        arch = "m68k",
        toolchain = "amigaos",
        sdk_name = "amigaos-sdk",
        sdk_env = "AMIGA_SDK"
    },
    atari = {
        id = "atari",
        name = "Atari ST / FreeMiNT (m68k)",
        plat = "atari",
        arch = "m68k",
        toolchain = "atarist",
        sdk_name = "atarist-sdk",
        sdk_env = "ATARIST_SDK"
    },
    kolibri = {
        id = "kolibri",
        name = "KolibriOS (x86)",
        plat = "kolibri",
        arch = "i386",
        toolchain = "kolibrios",
        sdk_name = "kolibrios-sdk",
        sdk_env = "KOLIBRI_SDK"
    },
    dos = {
        id = "dos",
        name = "MS-DOS 32-bit (Open Watcom + WATT-32)",
        plat = "dos",
        arch = "i386",
        toolchain = "watcom",
        sdk_name = "watcom",
        sdk_env = "WATCOM"
    },
    os2 = {
        id = "os2",
        name = "OS/2 32-bit Warp (Open Watcom)",
        plat = "os2",
        arch = "i386",
        toolchain = "watcom",
        sdk_name = "watcom",
        sdk_env = "WATCOM"
    },
    wince = {
        id = "wince",
        name = "Windows CE (MS eVC 3.0 ARM via wibo)",
        plat = "wince",
        arch = "arm",
        toolchain = "evc3",
        sdk_name = "evc3",
        sdk_env = "EVC3_DIR"
    },
    freebsd = {
        id = "freebsd",
        name = "FreeBSD (x86_64, arm64, riscv64, ppc)",
        plat = "freebsd",
        arch = "x86_64",
        toolchain = "freebsd",
        sdk_name = "freebsd-sdk",
        sdk_env = "FREEBSD_SDK"
    },
    openbsd = {
        id = "openbsd",
        name = "OpenBSD (x86_64, arm64, riscv64, sparc64)",
        plat = "openbsd",
        arch = "x86_64",
        toolchain = "openbsd",
        sdk_name = "openbsd-sdk",
        sdk_env = "OPENBSD_SDK"
    },
    netbsd = {
        id = "netbsd",
        name = "NetBSD (x86_64, arm, m68k, vax, mips)",
        plat = "netbsd",
        arch = "x86_64",
        toolchain = "netbsd",
        sdk_name = "netbsd-sdk",
        sdk_env = "NETBSD_SDK"
    },
    dragonflybsd = {
        id = "dragonflybsd",
        name = "DragonFly BSD (x86_64)",
        plat = "dragonflybsd",
        arch = "x86_64",
        toolchain = "dragonflybsd",
        sdk_name = "dragonflybsd-sdk",
        sdk_env = "DRAGONFLY_SDK"
    },
    posix = {
        id = "posix",
        name = "POSIX Host (Linux / BSD / macOS)",
        plat = "linux",
        arch = "x86_64",
        toolchain = nil
    }
}

local function find_program(name)
    local find_file = import("lib.detect.find_file")
    local pathes = path.splitenv(os.getenv("PATH") or "")
    if os.host() == "windows" and not name:endswith(".exe") then
        return find_file(name .. ".exe", pathes) or find_file(name, pathes)
    end
    return find_file(name, pathes)
end

local function is_sdk_available(t)
    if t.id == "posix" then
        return true
    end
    if t.plat == os.host() then
        return true
    end
    if t.sdk_name and sdk.exists(t.sdk_name, t.sdk_env) then
        return true
    end
    -- Check if cross-toolchain or tool exists in PATH
    if t.id == "netbsd" and (find_program("x86_64--netbsd-gcc") or os.getenv("NETBSD_TOOLDIR") ~= nil) then
        return true
    elseif t.id == "freebsd" and (find_program("x86_64-unknown-freebsd-gcc") or os.getenv("FREEBSD_SYSROOT") ~= nil) then
        return true
    elseif t.id == "openbsd" and (find_program("x86_64-unknown-openbsd-gcc") or os.getenv("OPENBSD_SYSROOT") ~= nil) then
        return true
    elseif t.id == "dragonflybsd" and (find_program("x86_64-unknown-dragonfly-gcc") or os.getenv("DRAGONFLY_SYSROOT") ~= nil) then
        return true
    end
    return false
end

local function get_sdk_path(t)
    if t.id == "posix" or t.plat == os.host() then
        return "Host Native Development Tools"
    end
    if t.sdk_name and sdk.exists(t.sdk_name, t.sdk_env) then
        return sdk.find(t.sdk_name, t.sdk_env)
    end
    if t.sdk_name then
        return sdk.find(t.sdk_name, t.sdk_env) or ("Cross SDK (" .. (t.sdk_env or t.sdk_name) .. ")")
    end
    return "Host Native Development Tools"
end

local function show_list()
    cprint("${bright magenta}╔══════════════════════════════════════════════════════════════════════════════╗")
    cprint("${bright magenta}║${bright yellow}            Projectum Lunare Forge - Cross-Compilation Toolchains             ${bright magenta}║")
    cprint("${bright magenta}╠══════════════════════════════════════════════════════════════════════════════╣")
    cprint("${bright magenta}║ ${dim}Target       Status Toolchain  SDK Location / Platform Notes                 ${bright magenta}║")
    cprint("${bright magenta}╟──────────────────────────────────────────────────────────────────────────────╢")

    local order = {
        "amiga", "atari", "kolibri", "dos", "os2", "wince",
        "freebsd", "openbsd", "netbsd", "dragonflybsd",
        "posix"
    }
    for _, key in ipairs(order) do
        local t = targets[key]
        local avail = is_sdk_available(t)
        local status_str = avail and "${bright green}✓ Ready${clear}" or "${bright red}✗ Miss ${clear}"
        local key_padded = string.format("%-12s", key)
        local default_tc = (t.id == "posix" and "host-gcc") or "clang/gcc"
        local tc_str = string.format("%-10s", t.toolchain or default_tc)
        local note = get_sdk_path(t) or ""
        if #note > 43 then
            note = "..." .. note:sub(-40)
        end
        local note_padded = string.format("%-43s", note)
        cprint("${bright magenta}║ ${bright cyan}" .. key_padded .. " " .. status_str .. " ${yellow}" .. tc_str .. " ${dim}" .. note_padded .. " ${bright magenta}║")
    end
    cprint("${bright magenta}╚══════════════════════════════════════════════════════════════════════════════╝${clear}")

    local lua_env = import("lua.env", {rootdir = path.join(os.scriptdir(), "../../modules")})
    local lua_bin = lua_env.find_lua()
    if lua_bin then
        local lua_ver = try { function() return os.iorunv(lua_bin, {"-v"}) end } or "found"
        cprint("${dim}Lua Subsystem: ${bright cyan}" .. lua_ver:trim() .. "${dim} via ${yellow}" .. lua_bin .. "${clear}")
    else
        cprint("${bright red}Lua Subsystem: No compatible Lua >= 5.4 interpreter detected in PATH or LUA_BIN${clear}")
    end

    print("\nUsage:")
    print("  xmake forge <target> [build_target]  # e.g. xmake forge amiga, xmake forge posix")
    print("  xmake forge all                      # build all available targets")
    print("  xmake forge list                     # show this table")
    io.write("  xmake forge env                      # output LUA_PATH & LUA_CPATH (eval $(xmake forge env))\n")
    print("  xmake forge env --export-env         # generate .env file for IDEs and LuaLS")
end

local function show_env()
    local lua_env = import("lua.env", {rootdir = path.join(os.scriptdir(), "../../modules")})
    local projdir = os.projectdir()

    if option.get("export-env") or option.get("export_env") then
        local env_file = path.join(projdir, ".env")
        lua_env.write_dotenv(projdir, env_file)
        cprint("${bright green}==> [forge] Exported environment to: ${bright white}%s${clear}", env_file)
        return
    end

    if option.get("json") then
        import("core.base.json")
        local data = lua_env.get_env(projdir)
        print(json.encode(data))
        return
    end

    if option.get("fish") then
        local p = lua_env.get_lua_paths(projdir)
        local cp = lua_env.get_lua_cpaths(projdir)
        print("set -gx LUA_PATH \"" .. p .. "\"")
        print("set -gx LUA_CPATH \"" .. cp .. "\"")
        return
    end

    -- Standard POSIX export: eval $(xmake forge env)
    local p = lua_env.get_lua_paths(projdir)
    local cp = lua_env.get_lua_cpaths(projdir)
    print("export LUA_PATH=\"" .. p .. "\"")
    print("export LUA_CPATH=\"" .. cp .. "\"")
end

local function build_target(key, opt)
    local t = targets[key]
    if not t then
        raise("Unknown forge target: " .. key .. " (run 'xmake forge list' to see available targets)")
    end

    if not is_sdk_available(t) then
        raise("SDK/Toolchain for target '" .. key .. "' not available. Expected at: " .. (get_sdk_path(t) or "unknown"))
    end

    cprint("${bright yellow}==> [forge] Configuring target: ${bright cyan}" .. t.name .. "${clear}")

    local config_args = {"f", "-p", t.plat}
    if t.arch then
        table.insert(config_args, "-a")
        table.insert(config_args, t.arch)
    end
    if t.toolchain then
        table.insert(config_args, "--toolchain=" .. t.toolchain)
    end
    if opt.clean then
        table.insert(config_args, "-c")
    end

    os.execv("xmake", config_args)

    local target_desc = opt.build_target and ("target '" .. opt.build_target .. "'") or "default target(s)"
    cprint("${bright yellow}==> [forge] Building " .. target_desc .. " for ${bright cyan}" .. key .. "${clear}...")
    local build_args = {"build"}
    if opt.verbose then
        table.insert(build_args, "-v")
    end
    if opt.build_target then
        table.insert(build_args, opt.build_target)
    end

    os.execv("xmake", build_args)

    cprint("${bright green}==> [forge] SUCCESS: Built " .. target_desc .. " for ${bright white}" .. t.name .. "${clear}\n")
end

function main()
    local target_name = option.get("target") or "list"
    local opt = {
        verbose = option.get("verbose"),
        clean = option.get("clean"),
        build_target = option.get("build_target")
    }

    -- Support shorthand alias
    if target_name == "atarist" then target_name = "atari" end
    if target_name == "amigaos" then target_name = "amiga" end
    if target_name == "kolibrios" then target_name = "kolibri" end
    if target_name == "linux" then target_name = "posix" end

    if target_name == "list" then
        show_list()
    elseif target_name == "env" or option.get("export-env") or option.get("export_env") or option.get("json") or option.get("fish") then
        show_env()
    elseif target_name == "all" then
        local order = {
            "amiga", "atari", "kolibri", "dos", "os2", "wince",
            "freebsd", "openbsd", "netbsd", "dragonflybsd",
            "posix"
        }
        local results = {}
        for _, key in ipairs(order) do
            local t = targets[key]
            if is_sdk_available(t) then
                local start_time = os.mclock()
                local ok = try {
                    function ()
                        build_target(key, opt)
                        return true
                    end
                }
                local elapsed = os.mclock() - start_time
                table.insert(results, {key = key, name = t.name, ok = ok, time = elapsed})
            else
                table.insert(results, {key = key, name = t.name, ok = false, skipped = true})
            end
        end

        cprint("\n${bright green}══════════════════════════════════════════════════════════════════════════════")
        cprint("${bright green}                       FORGE MATRIX BUILD SUMMARY")
        cprint("══════════════════════════════════════════════════════════════════════════════${clear}")
        for _, r in ipairs(results) do
            local status_text
            if r.skipped then
                status_text = "${dim}[SKIPPED - SDK MISSING]${clear}"
            elseif r.ok then
                status_text = string.format("${bright green}[PASS]${clear} in %.2fs", (r.time or 0) / 1000)
            else
                status_text = "${bright red}[FAIL]${clear}"
            end
            cprint(string.format("  * %-12s %-36s %s", r.key, r.name, status_text))
        end
        cprint("${bright green}══════════════════════════════════════════════════════════════════════════════${clear}\n")
    else
        build_target(target_name, opt)
    end
end
