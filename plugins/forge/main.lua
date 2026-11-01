-- Projectum Lunare Forge
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local rootdir = path.join(os.scriptdir(), "../../")

import("core.base.option")
import("modules.detect.bsd", {rootdir = rootdir})
import("modules.sdk", {rootdir = rootdir})
import("catalog", {rootdir = path.join(rootdir, "modules")})

local order = catalog.cli_order()
local aliases = catalog.aliases()
local targets = catalog.cli_targets()

local function kind_of(t)
    if t.probe then
        return t.probe
    elseif t.id == "posix" then
        return "posix"
    elseif t.id == "dos" or t.id == "os2" then
        return "watcom"
    elseif t.id == "wince" then
        return "evc3"
    elseif catalog.is_bsd(t.id) then
        return "bsd"
    elseif t.check_file then
        return "sdk"
    end
end

local function watcom_module()
    return import("modules.detect.watcom", {rootdir = rootdir})
end

local function find_wibo()
    local wibo_bin = os.getenv("WIBO_BIN")
    if not wibo_bin then
        local wibo_dir = sdk.find("wibo", "WIBO_DIR", {must_exist = true})
        if wibo_dir then
            wibo_bin = path.join(wibo_dir, "bin", "wibo")
        end
    end
    return wibo_bin
end

local function lua_environment()
    return import("lua.env", {rootdir = path.join(rootdir, "modules")})
end

function is_host_compatible(plat, arch)
    if not catalog.same_os(plat, os.host()) then
        return false
    end
    local norm_host = bsd.normalize_arch(os.arch(), plat)
    local norm_tgt = bsd.normalize_arch(arch or os.arch(), plat)
    return norm_host == norm_tgt
end

function is_evc3_available(t)
    local env_name = (t and t.sdk_env) or "EVC3_DIR"
    local evc_dir = sdk.find("evc3", env_name, {must_exist = true})
    if not evc_dir or not os.isdir(evc_dir) then
        return false
    end

    local clarm = path.join(evc_dir, "bin", "clarm.exe")
    local link = path.join(evc_dir, "bin", "link.exe")
    if not (os.isfile(clarm) and os.isfile(link)) then
        return false
    end

    if os.host() == "windows" then
        return true
    end

    local wibo_bin = find_wibo()
    return wibo_bin ~= nil and os.isexec(wibo_bin)
end

local probes = {
    watcom = function (t)
        return watcom_module().is_available(t.sdk_env)
    end,
    evc3 = function (t)
        return is_evc3_available(t)
    end,
    bsd = function (t, target_arch)
        return bsd.is_available(t.id, target_arch)
    end,
    sdk = function (t)
        return sdk.exists(t.sdk_name, t.sdk_env, {check_file = t.check_file})
    end
}

local function bsd_location(t, target_arch)
    local _, tool = bsd.find_toolchain(t.id, target_arch)
    if tool then
        return type(tool) == "table" and tool.program or tool
    end
    local sysroot = os.getenv(t.sdk_env or (t.id:upper() .. "_SYSROOT"))
    if sysroot and os.isdir(sysroot) then
        return sysroot
    end
    return "Cross toolchain for " .. target_arch .. " missing"
end

local function watcom_location(t, _, available)
    local w_sdk = watcom_module().find_sdk(t.sdk_env)
    if available then
        return w_sdk
    elseif w_sdk and os.isdir(w_sdk) then
        return w_sdk .. " (owcc missing)"
    else
        return (w_sdk or "WATCOM") .. " (not installed)"
    end
end

local function evc3_location(t, _, available)
    local evc_dir = sdk.find("evc3", t.sdk_env, {must_exist = true})
    if available then
        return evc_dir
    elseif not evc_dir then
        return "EVC3_DIR not installed"
    elseif os.host() ~= "windows" then
        local wibo_bin = find_wibo()
        if not (wibo_bin and os.isexec(wibo_bin)) then
            return evc_dir .. " (wibo missing)"
        end
        return evc_dir .. " (clarm.exe/link.exe missing)"
    else
        return evc_dir .. " (clarm.exe/link.exe missing)"
    end
end

local function sdk_location(t, _, available)
    local found = sdk.find(t.sdk_name, t.sdk_env, {must_exist = true})
    if available then
        return found
    elseif found and os.isdir(found) then
        return found .. " (" .. path.filename(t.check_file) .. " missing)"
    else
        return (sdk.find(t.sdk_name, t.sdk_env) or t.sdk_name) .. " (not installed)"
    end
end

local locations = {
    bsd = bsd_location,
    watcom = watcom_location,
    evc3 = evc3_location,
    sdk = sdk_location
}

function is_sdk_available(t, arch)
    local target_arch = arch or t.arch
    if kind_of(t) == "posix" then
        return is_host_compatible(os.host(), target_arch)
    end
    if is_host_compatible(t.plat, target_arch) then
        return true
    end
    local probe = probes[kind_of(t)]
    if probe then
        return probe(t, target_arch)
    end
    return false
end

function get_sdk_path(t, arch)
    local target_arch = arch or t.arch
    local available = is_sdk_available(t, target_arch)
    local kind = kind_of(t)

    if kind == "posix" then
        if available then
            return "Host Native Development Tools"
        else
            return "Host (" .. os.arch() .. ") cannot build " .. target_arch .. " without cross-compiler"
        end
    end

    if is_host_compatible(t.plat or os.host(), target_arch) then
        return "Host Native Development Tools"
    end

    local locate = locations[kind]
    if locate then
        return locate(t, target_arch, available)
    end
    return "Cross SDK (" .. (t.sdk_env or t.sdk_name) .. ")"
end

local function show_list(opt)
    opt = opt or {}
    cprint("${bright magenta}╔══════════════════════════════════════════════════════════════════════════════╗")
    cprint("${bright magenta}║${bright yellow}            Projectum Lunare Forge - Cross-Compilation Toolchains             ${bright magenta}║")
    cprint("${bright magenta}╠══════════════════════════════════════════════════════════════════════════════╣")
    cprint("${bright magenta}║ ${dim}Target       Status Toolchain  SDK Location / Platform Notes                 ${bright magenta}║")
    cprint("${bright magenta}╟──────────────────────────────────────────────────────────────────────────────╢")

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

    local lua_env = lua_environment()
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
    print("  xmake forge repl [-r luajit]         # launch interactive REPL with project environment")
    print("  xmake forge create <name> [-t app]   # create a new project from template (app, module, cmodule, love, amulet, love-compat, amulet-compat)")
end

local function show_env(env_opts)
    env_opts = env_opts or {}
    local lua_env = lua_environment()
    local projdir = os.projectdir()

    if env_opts.export_env then
        local env_file = path.join(projdir, ".env")
        lua_env.write_dotenv(projdir, env_file)
        cprint("${bright green}==> [forge] Exported environment to: ${bright white}%s${clear}", env_file)
        return
    end

    if env_opts.json then
        import("core.base.json")
        local data = lua_env.get_env(projdir)
        print(json.encode(data))
        return
    end

    local p = lua_env.get_lua_paths(projdir)
    local cp = lua_env.get_lua_cpaths(projdir)
    if env_opts.fish then
        print("set -gx LUA_PATH \"" .. p .. "\"")
        print("set -gx LUA_CPATH \"" .. cp .. "\"")
        return
    end

    -- Standard POSIX export: eval $(xmake forge env)
    print("export LUA_PATH=\"" .. p .. "\"")
    print("export LUA_CPATH=\"" .. cp .. "\"")
end

local function start_repl(repl_opts)
    repl_opts = repl_opts or {}
    local lua_env = lua_environment()
    local projdir = os.projectdir()
    local find_tool = import("lib.detect.find_tool")

    local runtime = repl_opts.runtime or "lua"
    local interp_bin = nil

    if repl_opts.interpreter then
        interp_bin = repl_opts.interpreter
    elseif runtime == "luajit" or runtime == "openresty" then
        local tool = find_tool("luajit")
        if tool and tool.program then
            interp_bin = tool.program
        end
    else
        interp_bin = lua_env.find_lua({interpreter = repl_opts.interpreter})
        if not interp_bin then
            local tool = find_tool("lua")
            if tool and tool.program then
                interp_bin = tool.program
            end
        end
    end

    if not interp_bin or not os.isexec(interp_bin) then
        raise("Interpreter for runtime '%s' not found. Please install %s or specify path via --interpreter.", runtime, runtime)
    end

    local p = lua_env.get_lua_paths(projdir)
    local cp = lua_env.get_lua_cpaths(projdir)

    local builddir = path.join(projdir, "build")
    if os.isdir(builddir) then
        local cdirs = {}
        for _, d in ipairs(os.dirs(path.join(builddir, "**"))) do
            table.insert(cdirs, path.join(d, "?.so"))
            table.insert(cdirs, path.join(d, "?.dylib"))
            table.insert(cdirs, path.join(d, "?.dll"))
        end
        if #cdirs > 0 then
            cp = table.concat(cdirs, ";") .. ";" .. cp
        end
    end

    local ver = try { function() return os.iorunv(interp_bin, {"-v"}) end } or ""
    ver = ver:trim():split("\n")[1] or ""

    cprint("${bright magenta}╔══════════════════════════════════════════════════════════════════════════════╗${clear}")
    cprint("${bright magenta}║${bright white}                 Projectum Lunare Forge - Interactive REPL                    ${bright magenta}║${clear}")
    cprint("${bright magenta}╚══════════════════════════════════════════════════════════════════════════════╝${clear}")
    cprint("${dim}Runtime    : ${bright cyan}%s${clear} ${dim}(%s)${clear}", runtime, ver)
    cprint("${dim}Binary     : ${yellow}%s${clear}", interp_bin)
    cprint("${dim}LUA_PATH   : ${dim}%s${clear}", p)
    cprint("${dim}LUA_CPATH  : ${dim}%s${clear}", cp)
    cprint("${dim}Type ${bright white}os.exit()${dim} or press ${bright white}Ctrl+D${dim} to exit.${clear}\n")

    local exec_envs = {
        LUA_PATH = p,
        LUA_CPATH = cp,
    }
    if runtime == "luajit" or runtime == "openresty" then
        exec_envs.LUAJIT_PATH = p
        exec_envs.LUAJIT_CPATH = cp
    end

    local exec_args = {"-i"}
    if repl_opts.eval_expr then
        exec_args = {"-e", repl_opts.eval_expr}
        os.execv(interp_bin, exec_args, {envs = exec_envs})
        return
    end
end

local function create_project(project_name, template_name, target_dir)
    if not project_name or #project_name == 0 then
        raise("Missing project name. Usage: xmake forge create <project_name> [-t app|module|cmodule|love|amulet|love-compat|amulet-compat]")
    end
    template_name = template_name or "app"
    template_name = template_name:gsub("_", "-")
    local templates_root = path.join(rootdir, "templates", "lua")
    local tmpl_dir = path.join(templates_root, template_name)
    if not os.isdir(tmpl_dir) then
        local available = {}
        for _, dir in ipairs(os.dirs(path.join(templates_root, "*"))) do
            table.insert(available, path.basename(dir))
        end
        raise("Template '%s' not found. Available templates: %s", template_name, table.concat(available, ", "))
    end

    target_dir = target_dir or path.join(os.projectdir(), project_name)
    if os.isdir(target_dir) and #os.files(path.join(target_dir, "*")) > 0 then
        raise("Directory '%s' already exists and is not empty.", target_dir)
    end
    os.mkdir(target_dir)

    for _, srcfile in ipairs(os.files(path.join(tmpl_dir, "**"))) do
        local relpath = path.relative(srcfile, tmpl_dir)
        if relpath ~= "template.lua" then
            local dstfile = path.join(target_dir, relpath)
            os.mkdir(path.directory(dstfile))
            local content = io.readfile(srcfile)
            content = content:gsub("%${TARGET_NAME}", project_name)
            io.writefile(dstfile, content)
        end
    end

    cprint("${bright green}==> [forge] Successfully created '%s' (%s project) at: ${bright white}%s${clear}", project_name, template_name, target_dir)
    cprint("${bright cyan}To build and run your project:${clear}")
    cprint("  cd %s", project_name)
    cprint("  xmake")
    cprint("  xmake run")
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
    local should_isolate = (opt.isolate ~= false)
    if should_isolate then
        local target_builddir = path.join("build", key)
        os.mkdir(target_builddir)
        table.insert(config_args, "-o")
        table.insert(config_args, target_builddir)
        exec_opt.envs = {XMAKE_CONFIGDIR = path.absolute(path.join(target_builddir, ".xmake"), os.projectdir())}
        if opt.silent_log then
            logfile = path.join(target_builddir, "forge.log")
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

local function named(value, names)
    if not value then
        return false
    end
    for _, name in ipairs(names) do
        if value == name then
            return true
        end
    end
    return false
end

-- option_names are menu keys. value_names are raw argv / build_target spellings.
local function flag_enabled(args, option_names, value_names)
    for _, name in ipairs(option_names) do
        if option.get(name) then
            return true
        end
    end
    if named(option.get("build_target"), value_names) then
        return true
    end
    for _, arg in ipairs(args) do
        if named(arg, value_names) then
            return true
        end
    end
    return false
end

function main(...)
    local args = {...}
    local target_name = option.get("target") or "list"

    for _, arg in ipairs(args) do
        if arg == "list" or arg == "env" or arg == "repl" or arg == "create" or arg == "all" or targets[arg] then
            target_name = arg
        end
    end

    local is_json = flag_enabled(args, {"json"}, {"json", "--json"})
    local is_export_env = flag_enabled(args, {"export-env", "export_env"}, {"export-env", "--export-env", "--export_env"})
    local is_fish = flag_enabled(args, {"fish"}, {"fish", "--fish"})

    local raw_arch = option.get("arch")
    local resolved_arch = raw_arch and bsd.normalize_arch(raw_arch) or nil

    local raw_build_target = option.get("build_target")
    local clean_build_target = (raw_build_target and not raw_build_target:startswith("-")) and raw_build_target or nil

    local eval_expr = option.get("eval") or option.get("e")
    local runtime = option.get("runtime") or option.get("r")
    if raw_build_target and not eval_expr then
        if raw_build_target:startswith("--eval=") then
            eval_expr = raw_build_target:sub(8)
            clean_build_target = nil
        elseif raw_build_target:startswith("-e=") then
            eval_expr = raw_build_target:sub(4)
            clean_build_target = nil
        end
    end
    if raw_build_target and not runtime then
        if raw_build_target:startswith("--runtime=") then
            runtime = raw_build_target:sub(11)
            clean_build_target = nil
        elseif raw_build_target:startswith("-r=") then
            runtime = raw_build_target:sub(4)
            clean_build_target = nil
        end
    end
    if not eval_expr or not runtime then
        for _, arg in ipairs(args) do
            if not eval_expr then
                if arg:startswith("--eval=") then
                    eval_expr = arg:sub(8)
                elseif arg:startswith("-e=") then
                    eval_expr = arg:sub(4)
                end
            end
            if not runtime then
                if arg:startswith("--runtime=") then
                    runtime = arg:sub(11)
                elseif arg:startswith("-r=") then
                    runtime = arg:sub(4)
                end
            end
        end
    end

    local opt = {
        verbose = option.get("verbose"),
        clean = option.get("clean"),
        arch = resolved_arch,
        build_target = clean_build_target,
        isolate = not (option.get("no-isolate") or option.get("no_isolate")),
        json = is_json,
        export_env = is_export_env,
        fish = is_fish,
        runtime = runtime,
        interpreter = option.get("interpreter"),
        eval_expr = eval_expr,
        template = option.get("template") or "app",
        raw_args = args
    }

    target_name = aliases[target_name] or target_name

    if target_name == "list" then
        show_list(opt)
    elseif target_name == "env" or is_export_env or is_json or is_fish then
        show_env(opt)
    elseif target_name == "repl" then
        start_repl(opt)
    elseif target_name == "create" then
        local proj_name = opt.build_target
        local tmpl_choice = opt.template
        local extra = option.get("extra_args")
        if (not tmpl_choice or tmpl_choice == "app") and extra and #extra > 0 then
            for idx, val in ipairs(extra) do
                if (val == "-t" or val == "--template") and extra[idx + 1] then
                    tmpl_choice = extra[idx + 1]
                    break
                elseif val:startswith("--template=") then
                    tmpl_choice = val:sub(12)
                    break
                elseif val:startswith("-t=") then
                    tmpl_choice = val:sub(4)
                    break
                elseif not val:startswith("-") then
                    tmpl_choice = val
                    break
                end
            end
        end
        local pos_args = {}
        for _, a in ipairs(args) do
            if a ~= "create" and not a:startswith("-") then
                table.insert(pos_args, a)
            end
        end
        if not proj_name and #pos_args > 0 then
            proj_name = pos_args[1]
            if #pos_args > 1 and (not tmpl_choice or tmpl_choice == "app") then
                tmpl_choice = pos_args[2]
            end
        elseif proj_name and #pos_args > 1 and (not tmpl_choice or tmpl_choice == "app") then
            if pos_args[1] == proj_name and pos_args[2] then
                tmpl_choice = pos_args[2]
            end
        end
        create_project(proj_name, tmpl_choice)
    elseif target_name == "all" then
        local results = {}
        local all_opt = table.clone(opt)
        all_opt.isolate = true
        all_opt.silent_log = not opt.verbose

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
