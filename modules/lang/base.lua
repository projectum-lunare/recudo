-- Projectum Lunare Recudo - Language Rules & Testing Base Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local modules_root = path.join(os.scriptdir(), "..")
local tree = import("lua.tree", {rootdir = modules_root, anonymous = true})

-- Strip common leading indentation from multiline string
function dedent(str)
    if not str then
        return nil
    end
    local lines = str:split("\n", {plain = true})
    local min_indent = nil
    for _, line in ipairs(lines) do
        if line:find("%S") then
            local indent = #(line:match("^(%s*)") or "")
            if min_indent == nil or indent < min_indent then
                min_indent = indent
            end
        end
    end
    if min_indent and min_indent > 0 then
        local trimmed = {}
        for _, line in ipairs(lines) do
            if #line >= min_indent then
                table.insert(trimmed, line:sub(min_indent + 1))
            else
                table.insert(trimmed, (line:gsub("^%s+", "")))
            end
        end
        return table.concat(trimmed, "\n")
    end
    return str
end

-- Generic program finder across package, deps, target, xrepo cache, and PATH
function find_program(opt, progname, pkg_names)
    opt = opt or {}
    progname = progname or "lua"
    pkg_names = table.wrap(pkg_names or progname)

    local pkg
    local target
    if type(opt) == "table" or type(opt) == "userdata" then
        if opt.is_plat or opt.orderdeps then
            pkg = opt
        elseif opt.pkg or opt.autogendir then
            target = opt
        end
    end

    local is_win = (pkg and pkg.is_plat and pkg:is_plat("windows", "mingw")) or is_host("windows")
    local win_exts = {".exe", ".bat", ".cmd"}

    local function check_bin(dir)
        if not dir or not os.isdir(dir) then
            return nil
        end
        if is_win then
            for _, ext in ipairs(win_exts) do
                local p = path.join(dir, progname .. ext)
                if os.isfile(p) or os.isexec(p) then
                    return p
                end
            end
        end
        local p = path.join(dir, progname)
        if os.isfile(p) or os.isexec(p) then
            return p
        end
        return nil
    end

    -- 1. Check if pkg itself matches
    if pkg and pkg.installdir then
        local p = check_bin(pkg:installdir("bin"))
        if p then
            return p
        end
    end

    -- 2. Check dependencies of pkg
    if pkg and pkg.dep then
        for _, name in ipairs(pkg_names) do
            local dep = pkg:dep(name)
            if dep and dep.installdir then
                local p = check_bin(dep:installdir("bin"))
                if p then
                    return p
                end
            end
        end
    end

    -- 3. Check target pkg
    if target and target.pkg then
        for _, name in ipairs(pkg_names) do
            local tpkg = target:pkg(name)
            if tpkg and tpkg.installdir then
                local p = check_bin(tpkg:installdir("bin"))
                if p then
                    return p
                end
            end
        end
    end

    -- 4. Check xrepo cache
    for _, name in ipairs(pkg_names) do
        local first_char = name:sub(1, 1):lower()
        local xmake_pkg = path.join(os.getenv("HOME") or "", ".xmake/packages", first_char, name)
        if os.isdir(xmake_pkg) then
            local matches = os.files(path.join(xmake_pkg, "**/bin/" .. progname .. "*"))
            if matches and #matches > 0 then
                -- Check exact matches first
                for _, m in ipairs(matches) do
                    local fn = path.filename(m)
                    if fn == progname or fn == progname .. ".exe" or fn == progname .. ".bat" then
                        if os.isexec(m) or os.isfile(m) then
                            return m
                        end
                    end
                end
            end
        end
    end

    -- 5. System PATH
    import("lib.detect.find_tool")
    local tool = find_tool(progname)
    if not tool then
        for _, name in ipairs(pkg_names) do
            tool = find_tool(name)
            if tool then
                break
            end
        end
    end
    if tool and tool.program then
        return tool.program
    end

    return is_win and (progname .. (progname == "yue" and ".exe" or ".bat")) or progname
end

-- Build runtime environment with package and dependencies paths
function search_envs(package)
    local is_win = package:is_plat("windows", "mingw")
    local ext = is_win and ".dll" or ".so"
    local lua_paths = {}
    local lua_cpaths = {}
    local ld_paths = {}

    local search = tree.module_search_envs(ext)

    local function add_package_paths(pkg)
        local dir = pkg.installdir and pkg:installdir()
        if dir and os.isdir(dir) then
            local note = path.join(dir, "share/recudo/lua-search.lua")
            local data = os.isfile(note) and io.load(note) or nil
            local envs = type(data) == "table" and data.envs or search
            for _, p in ipairs(table.wrap(envs.LUA_PATH)) do
                local full = path.normalize(path.join(dir, p))
                if not table.contains(lua_paths, full) then
                    table.insert(lua_paths, full)
                end
            end
            for _, p in ipairs(table.wrap(envs.LUA_CPATH)) do
                local full = path.normalize(path.join(dir, p))
                if not table.contains(lua_cpaths, full) then
                    table.insert(lua_cpaths, full)
                end
            end
            for _, sub in ipairs({"lib", "bin"}) do
                local p = path.join(dir, sub)
                if os.isdir(p) and not table.contains(ld_paths, p) then
                    table.insert(ld_paths, p)
                end
            end
        end
    end

    add_package_paths(package)
    if package.orderdeps then
        for _, dep in ipairs(table.wrap(package:orderdeps())) do
            add_package_paths(dep)
        end
    end

    local function lua_list(name, extra)
        local cur = os.getenv(name)
        local list = {}
        for _, p in ipairs(extra) do
            table.insert(list, p)
        end
        if cur then
            if not is_win then
                cur = cur:gsub(":", ";")
            end
            for p in cur:gmatch("[^;]+") do
                if path.is_absolute(p) and not table.contains(list, p) then
                    table.insert(list, p)
                end
            end
        end
        local result = table.concat(list, ";")
        if not result:endswith(";;") then
            result = result .. ";;"
        end
        return result
    end

    local envs = {
        LUA_PATH = lua_list("LUA_PATH", lua_paths),
        LUA_CPATH = lua_list("LUA_CPATH", lua_cpaths)
    }

    local sep = is_win and ";" or ":"
    local ld_var = is_win and "PATH" or (package:is_plat("macosx") and "DYLD_LIBRARY_PATH" or "LD_LIBRARY_PATH")
    local cur_ld = os.getenv(ld_var)
    if #ld_paths > 0 then
        local ld_val = table.concat(ld_paths, sep)
        if cur_ld and cur_ld ~= "" then
            ld_val = ld_val .. sep .. cur_ld
        end
        envs[ld_var] = ld_val
    end

    local bindir = package.installdir and package:installdir("bin")
    if bindir and os.isdir(bindir) then
        local cur_path = envs.PATH or os.getenv("PATH")
        if cur_path and cur_path ~= "" then
            envs.PATH = bindir .. path.envsep() .. cur_path
        else
            envs.PATH = bindir
        end
    end

    return envs
end

-- Generic test runner for language packages
function test(package, spec)
    if package:is_cross() then
        return
    end

    local expr = spec.expr
    local opt = spec.opt or {}
    if (type(expr) == "table" and opt == nil) or (type(expr) == "table" and next(opt) == nil) then
        opt = expr
        expr = opt.expr
    end

    local prog = spec.program
    if not prog then
        raise("program executable not found")
    end

    local envs = search_envs(package)
    if opt.envs then
        table.join2(envs, opt.envs)
    end

    -- 1. Version check
    if opt.version ~= false and spec.version_arg then
        local v_args = table.wrap(spec.version_arg)
        os.vrunv(prog, v_args, {envs = envs})
    end

    -- 2. Custom execution runner or standard eval
    if spec.runner then
        spec.runner(prog, envs, expr or spec.default_expr, opt)
    elseif spec.eval_arg then
        local code = dedent(expr or spec.default_expr)
        local eval_args = {}
        for _, a in ipairs(table.wrap(spec.eval_arg)) do
            table.insert(eval_args, a)
        end
        table.insert(eval_args, code)
        os.vrunv(prog, eval_args, {envs = envs})
    end
end

-- Helper to determine generated output directory for rule
function outdir(target, lang_name)
    local key = "recudo.lang." .. lang_name .. ".outdir"
    local dir = target:values(key)
    if not dir then
        if target:data("recudo.lua.is_cmodule")
            or target:data("recudo.lua.is_pure")
            or target:data("recudo.lua.is_app")
            or target:data("recudo.engine.love")
            or target:data("recudo.engine.amulet")
            or (target.rule and (target:rule("recudo.engine.love") or target:rule("recudo.engine.amulet"))) then
            dir = path.join(os.projectdir(), "build/lua")
        else
            dir = path.join(target:autogendir(), "rules", lang_name)
        end
    end
    return dir
end

-- Helper to ensure target has a package attached
function ensure_package(target, default_pkg, aliases)
    local all_names = table.wrap(aliases or default_pkg)
    for _, pkg in ipairs(table.wrap(target:get("packages"))) do
        for _, name in ipairs(all_names) do
            if pkg == name then
                return
            end
        end
    end
    target:add("packages", default_pkg)
end

-- Helper for before_buildcmd_file in transpiler rules
function build_transpiled(target, batchcmds, sourcefile, opt, spec)
    import("lua.env")
    local lang = spec.lang
    local ext = spec.ext
    local relpath = env.get_relative_path(target, sourcefile)
    local esc_ext = ext:gsub("%.", "%%.")
    local lua_rel = (relpath:gsub(esc_ext .. "$", ".lua"))
    local outfile = path.join(outdir(target, lang), lua_rel)

    local argv
    if type(spec.argv) == "function" then
        argv = spec.argv(outfile)
    else
        argv = spec.argv or {}
    end

    local vrun_opt = {}
    if spec.stdout then
        vrun_opt.stdout = outfile
    end

    batchcmds:show_progress(opt.progress, "${color.build.target}transpiling." .. lang .. " %s", sourcefile)
    batchcmds:mkdir(path.directory(outfile))
    batchcmds:vrunv(spec.program, argv, vrun_opt)
    batchcmds:add_depfiles(sourcefile)
    batchcmds:set_depmtime(os.mtime(outfile))
    batchcmds:set_depcache(target:dependfile(outfile))
end

-- Helper for before_buildcmd_file in native rules (transpile to C and compile to objectfile)
function build_native(target, batchcmds, sourcefile, opt, spec)
    import("lua.env")
    local lang = spec.lang
    local ext = spec.ext
    local relpath = env.get_relative_path(target, sourcefile)
    local esc_ext = ext:gsub("%.", "%%.")
    local c_rel = (relpath:gsub(esc_ext .. "$", ".c"))
    local sourcefile_c = path.join(target:autogendir(), "rules", lang, c_rel)

    local objectfile = target:objectfile(sourcefile_c)
    if not table.contains(target:objectfiles(), objectfile) then
        table.insert(target:objectfiles(), objectfile)
    end

    local argv
    if type(spec.argv) == "function" then
        argv = spec.argv(sourcefile_c)
    else
        argv = spec.argv or {}
    end

    batchcmds:show_progress(opt.progress, "${color.build.object}compiling." .. lang .. " %s", sourcefile)
    batchcmds:mkdir(path.directory(sourcefile_c))
    batchcmds:vrunv(spec.program, argv)
    batchcmds:compile(sourcefile_c, objectfile)
    batchcmds:add_depfiles(sourcefile)
    batchcmds:set_depmtime(os.mtime(sourcefile_c))
    batchcmds:set_depcache(target:dependfile(sourcefile_c))
end

-- Helper for after_install in rules: copy generated .lua files to share/lua and lib
function install_transpiled(target, src_ext, lang_name)
    import("lua.env")
    local installdir = target:installdir()
    if not installdir then
        return
    end

    local out_dir = outdir(target, lang_name)
    local esc_ext = src_ext:gsub("%.", "%%.")
    for _, src in ipairs(table.wrap(target:sourcefiles())) do
        if src:endswith(src_ext) then
            local relpath = env.get_relative_path(target, src)
            local lua_rel = (relpath:gsub(esc_ext .. "$", ".lua"))
            local gen_file = path.join(out_dir, lua_rel)
            if not os.isfile(gen_file) then
                gen_file = path.join(target:autogendir(), "rules", lang_name, lua_rel)
            end
            if os.isfile(gen_file) then
                local dst_share = path.join(installdir, "share/lua", lua_rel)
                local dst_lib = path.join(installdir, "lib", lua_rel)
                os.mkdir(path.directory(dst_share))
                os.mkdir(path.directory(dst_lib))
                os.cp(gen_file, dst_share)
                os.cp(gen_file, dst_lib)
            end
        end
    end
end
