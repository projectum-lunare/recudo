-- Projectum Lunare Forge - Cross-Compilation & Toolchain Engine
-- Reference: https://xmake.io/guide/extensions/addons/introduction.html

import("core.base.option")
import("modules.sdk", {rootdir = path.join(os.scriptdir(), "../..")})
import("modules.detect.bsd", {rootdir = path.join(os.scriptdir(), "../..")})

local host_os = os.host()
local host_arch = os.arch()

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
        name = string.format("POSIX Host (%s / %s)", host_os, host_arch),
        plat = host_os,
        arch = host_arch,
        toolchain = nil
    }
}

local function is_sdk_available(t, arch)
    if t.id == "posix" then
        return true
    end
    if t.plat == os.host() then
        return true
    end
    local target_arch = arch or t.arch
    if t.id == "freebsd" or t.id == "openbsd" or t.id == "netbsd" or t.id == "dragonflybsd" then
        if bsd.is_available(t.id, target_arch) then
            return true
        end
    end
    if t.sdk_name and sdk.exists(t.sdk_name, t.sdk_env) then
        return true
    end
    return false
end

local function get_sdk_path(t, arch)
    if t.id == "posix" or t.plat == os.host() then
        return "Host Native Development Tools"
    end
    local target_arch = arch or t.arch
    if t.id == "freebsd" or t.id == "openbsd" or t.id == "netbsd" or t.id == "dragonflybsd" then
        local pfx, tool = bsd.find_toolchain(t.id, target_arch)
        if tool then
            return type(tool) == "table" and tool.program or tool
        end
    end
    if t.sdk_name and sdk.exists(t.sdk_name, t.sdk_env) then
        return sdk.find(t.sdk_name, t.sdk_env)
    end
    if t.sdk_name then
        return sdk.find(t.sdk_name, t.sdk_env) or ("Cross SDK (" .. (t.sdk_env or t.sdk_name) .. ")")
    end
    return "Host Native Development Tools"
end

local function show_list(opt)
    opt = opt or {}
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
        local target_arch = opt.arch or t.arch
        local avail = is_sdk_available(t, target_arch)
        local status_str = avail and "${bright green}✓ Ready${clear}" or "${bright red}✗ Miss ${clear}"
        local key_padded = string.format("%-12s", key)
        local default_tc = (t.id == "posix" and "host-gcc") or "clang/gcc"
        local tc_str = string.format("%-10s", t.toolchain or default_tc)
        local note = get_sdk_path(t, target_arch) or ""
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

    local target_arch = opt.arch or t.arch
    if not is_sdk_available(t, target_arch) then
        raise("SDK/Toolchain for target '" .. key .. "' not available. Expected at: " .. (get_sdk_path(t, target_arch) or "unknown"))
    end

    cprint("${bright yellow}==> [forge] Configuring target: ${bright cyan}" .. t.name .. "${clear}")

    local config_args = {"f", "-p", t.plat}
    if target_arch then
        table.insert(config_args, "-a")
        table.insert(config_args, target_arch)
    end
    if t.toolchain then
        table.insert(config_args, "--toolchain=" .. t.toolchain)
    end
    local exec_opt = {}
    local logfile
    if opt.isolate_builddir then
        local target_builddir = path.join("build", key)
        os.mkdir(target_builddir)
        logfile = path.join(target_builddir, "forge.log")
        table.insert(config_args, "-o")
        table.insert(config_args, target_builddir)
        exec_opt.envs = {XMAKE_CONFIGDIR = path.absolute(target_builddir, os.projectdir())}
        if not opt.verbose then
            exec_opt.stdout = logfile
            exec_opt.stderr = logfile
        end
    end
    if opt.clean then
        table.insert(config_args, "-c")
    end

    os.execv("xmake", config_args, exec_opt)

    local target_desc = opt.build_target and ("target '" .. opt.build_target .. "'") or "default target(s)"
    cprint("${bright yellow}==> [forge] Building " .. target_desc .. " for ${bright cyan}" .. key .. "${clear}...")
    local build_args = {"build"}
    if opt.verbose then
        table.insert(build_args, "-v")
    end
    if opt.build_target then
        table.insert(build_args, opt.build_target)
    end

    os.execv("xmake", build_args, exec_opt)

    cprint("${bright green}==> [forge] SUCCESS: Built " .. target_desc .. " for ${bright white}" .. t.name .. "${clear}\n")
    return logfile
end

function main()
    -- print(option.options())
    local target_name = option.get("target") or "list"
    local raw_arch = option.get("arch")
    local resolved_arch = raw_arch and bsd.normalize_arch(raw_arch) or nil

    local opt = {
        verbose = option.get("verbose"),
        clean = option.get("clean"),
        arch = resolved_arch,
        build_target = option.get("build_target")
    }

    -- Support shorthand alias
    if target_name == "atarist" then target_name = "atari" end
    if target_name == "amigaos" then target_name = "amiga" end
    if target_name == "kolibrios" then target_name = "kolibri" end
    if target_name == "linux" then target_name = "posix" end

    if target_name == "list" then
        show_list(opt)
    elseif target_name == "env" or option.get("export-env") or option.get("export_env") or option.get("json") or option.get("fish") then
        show_env()
    elseif target_name == "all" then
        local order = {
            "amiga", "atari", "kolibri", "dos", "os2", "wince",
            "freebsd", "openbsd", "netbsd", "dragonflybsd",
            "posix"
        }
        local results = {}
        local all_opt = table.clone(opt)
        all_opt.isolate_builddir = true

        for _, key in ipairs(order) do
            local t = targets[key]
            local target_arch = all_opt.arch or t.arch
            if is_sdk_available(t, target_arch) then
                local start_time = os.mclock()
                local err_msg = nil
                local logfile = path.join("build", key, "forge.log")
                local ok = try {
                    function ()
                        local lf = build_target(key, all_opt)
                        if lf then logfile = lf end
                        return true
                    end,
                    catch {
                        function (err)
                            err_msg = tostring(err or "Unknown build error")
                        end
                    }
                }
                local elapsed = os.mclock() - start_time
                table.insert(results, {key = key, name = t.name, ok = ok, time = elapsed, error = err_msg, logfile = logfile})
            else
                table.insert(results, {key = key, name = t.name, ok = false, skipped = true})
            end
        end

        local has_failures = false
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
                has_failures = true
                status_text = "${bright red}[FAIL]${clear}"
            end
            cprint(string.format("  * %-12s %-36s %s", r.key, r.name, status_text))
        end
        cprint("${bright green}══════════════════════════════════════════════════════════════════════════════${clear}\n")

        if has_failures then
            cprint("${bright red}══════════════════════════════════════════════════════════════════════════════")
            cprint("${bright red}                       FORGE MATRIX FAILURE DETAILS")
            cprint("══════════════════════════════════════════════════════════════════════════════${clear}")
            for _, r in ipairs(results) do
                if not r.ok and not r.skipped then
                    cprint("${bright yellow}► Target: ${bright cyan}%s${yellow} (%s)${clear}", r.key, r.name)
                    if r.error then
                        cprint("  ${dim}Error:${clear} ${bright red}%s${clear}", r.error)
                    end
                    if r.logfile and os.isfile(r.logfile) then
                        cprint("  ${dim}Log file:${clear} ${bright white}%s${clear}", r.logfile)
                        local log_content = io.readfile(r.logfile)
                        if log_content then
                            local lines = log_content:trim():split("\n", {plain = true})
                            local start_idx = math.max(1, #lines - 10)
                            cprint("  ${dim}Last %d log lines:${clear}", #lines - start_idx + 1)
                            for i = start_idx, #lines do
                                cprint("    ${dim}%s${clear}", lines[i])
                            end
                        end
                    end
                    print("")
                end
            end
            cprint("${bright red}══════════════════════════════════════════════════════════════════════════════${clear}\n")
            raise("Forge matrix build failed for one or more targets.")
        end
    else
        build_target(target_name, opt)
    end
end
