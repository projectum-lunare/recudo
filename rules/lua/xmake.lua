-- Projectum Lunare Forge - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- First-class Lua package management, module compilation, path orchestration
-- and application bundling for modern POSIX, Windows, and vintage targets.

local function sandbox_patterns(staged, root, kind)
    local parts = {}
    local versions = (staged and staged.versions) or {}
    local exts = (staged and staged.exts) or {}
    if #versions == 0 then
        table.insert(versions, "5.4")
    end
    if #exts == 0 then
        table.insert(exts, (os.host() == "windows") and "dll" or "so")
    end
    for _, ver in ipairs(versions) do
        if kind == "path" then
            table.insert(parts, root .. "/share/lua/" .. ver .. "/?.lua")
            table.insert(parts, root .. "/share/lua/" .. ver .. "/?/init.lua")
        else
            for _, ext in ipairs(exts) do
                table.insert(parts, root .. "/lib/lua/" .. ver .. "/?." .. ext)
            end
        end
    end
    return table.concat(parts, ";")
end

local function package_search(lua_module, target)
    local roots = lua_module.roots_of(target)
    return roots,
        table.concat(lua_module.search_patterns(roots, "path"), ";"),
        table.concat(lua_module.search_patterns(roots, "cpath"), ";")
end

-- ==============================================================================
-- 1. Rule: forge.lua.module
-- Supports pure Lua modules, C native modules (.so/.dll), and hybrid modules.
-- ==============================================================================
local function setup_module_rule(rule_name)
    rule(rule_name)
        set_extensions(".lua")

        on_load(function (target)
            import("lua.env")

            -- Scan target files to identify native C/C++ sources
            local has_c_sources = false
            for _, f in ipairs(table.wrap(target:get("files"))) do
                if f:endswith(".c") or f:endswith(".cpp") or f:endswith(".cc") or f:endswith(".cxx") then
                    has_c_sources = true
                    break
                end
            end

            if has_c_sources then
                -- Native C module or hybrid
                target:data_set("forge.lua.is_cmodule", true)

                -- Project --kind selects static or shared. Platforms that cannot
                -- dlopen stay static. An explicit forge.lua.kind can narrow one target.
                local lua_module = import("lua.module", {anonymous = true})
                import("core.project.config")
                local marked_shared = config.get("kind") == "shared"
                local user_kind = target:values("forge.lua.kind")
                if user_kind == "static" then
                    marked_shared = false
                elseif user_kind == "shared" then
                    marked_shared = true
                end
                local is_static = not lua_module.supports_dynamic(target:plat()) or not marked_shared

                if is_static then
                    -- Static archive mode (.a / .lib)
                    target:set("kind", "static")
                    target:data_set("forge.lua.is_static", true)
                    local clean_name = target:name():gsub("%.", "_"):gsub("%-", "_")
                    target:set("basename", clean_name)
                    target:data_set("forge.lua.open_symbol", "luaopen_" .. clean_name)
                    if not target:is_plat("amiga", "atari", "kolibri", "dos", "os2", "wince") and not target:is_plat("windows") then
                        target:add("cxflags", "-fPIC")
                    end
                else
                    -- Dynamic shared module (.so / .dll)
                    target:set("kind", "shared")
                    local parts = target:name():split('.', {plain = true})
                    local leaf = parts[#parts]
                    local subdirs = #parts > 1 and table.concat(table.slice(parts, 1, #parts - 1), "/") or ""

                    target:set("targetdir", path.join("build/lua", subdirs))
                    target:set("basename", leaf)
                    target:set("prefixname", "")
                    target:set("symbols", "none")
                    if subdirs ~= "" then
                        target:set("prefixdir", ".", {libdir = path.join("lib", subdirs)})
                    end

                    if target:is_plat("windows", "mingw") then
                        target:set("extension", ".dll")
                        local exp_symbol = "luaopen_" .. target:name():gsub("%.", "_"):gsub("%-", "_")
                        target:add("shflags", "/export:" .. exp_symbol, {force = true})
                    else
                        target:set("extension", ".so")
                        target:add("cxflags", "-fPIC")
                    end
                end

                -- Ensure Lua headers and defines for C modules
                local has_lua_pkg = false
                for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                    if pkg == "lua" or pkg == "luajit" then
                        has_lua_pkg = true
                        break
                    end
                end
                if not has_lua_pkg then
                    target:add("packages", "lua")
                end
                target:add("defines", "LUA_COMPAT_5_3")
                if target:is_plat("wince") then
                    target:add("rules", "forge.evc3", {override = true})
                elseif target:is_plat("dos", "os2") then
                    target:add("rules", "forge.watcom", {override = true})
                end
                local vintage = target:is_plat("wince", "dos", "os2", "amiga", "atari", "kolibri", "plan9")
                if vintage then
                    target:add("defines", "LUA_USE_C89")
                end
                if vintage or target:is_arch("m68k.*", "i386", "x86", "mips.*", "ppc.*", "powerpc", "armv4.*", "armv5.*", "sh.*") then
                    target:add("defines", "LUA_32BITS")
                end
            else
                -- Pure Lua library
                target:set("kind", "phony")
                target:data_set("forge.lua.is_pure", true)
            end

            -- Automatically export canonical environment paths to target runtime
            target:add("runenvs", "LUA_PATH", env.get_lua_paths())
            target:add("runenvs", "LUA_CPATH", env.get_lua_cpaths())
        end)

        on_config(function (target)
            if target:data("forge.lua.is_cmodule") then
                local lua_pkg = target:pkg("lua")
                if lua_pkg then
                    local dirs = table.join(table.wrap(lua_pkg:get("sysincludedirs")), table.wrap(lua_pkg:get("includedirs")))
                    for _, inc in ipairs(dirs) do
                        target:add("includedirs", inc)
                        local subinc = path.join(inc, "lua")
                        if os.isdir(subinc) then
                            target:add("includedirs", subinc)
                        end
                    end
                end
            end
        end)

        before_build(function (target)
            import("lua.env")
            env.stage_lua_sourcefiles(target, target:sourcefiles())
        end)

        after_install(function (target)
            import("lua.env")

            -- Install only Lua files belonging to this target
            for _, f in ipairs(table.wrap(target:sourcefiles())) do
                if f:endswith(".lua") then
                    local rel = env.get_relative_path(target, f)
                    if not rel:find("..", 1, true) then
                    -- Canonical installation: share/lua/
                    local dst1 = path.join(target:installdir(), "share/lua", rel)
                    os.mkdir(path.directory(dst1))
                    os.cp(f, dst1)

                    -- Flat installation: lib/
                    local dst2 = path.join(target:installdir(), "lib", rel)
                    os.mkdir(path.directory(dst2))
                    os.cp(f, dst2)

                    -- Namespaced mirror if parent_module is explicitly configured
                    local parent = target:values("forge.lua.parent_module") or target:data("forge.lua.parent_module")
                    if parent then
                        local dst_sub1 = path.join(target:installdir(), "share/lua", parent, rel)
                        os.mkdir(path.directory(dst_sub1))
                        os.cp(f, dst_sub1)

                        local dst_sub2 = path.join(target:installdir(), "lib", parent, rel)
                        os.mkdir(path.directory(dst_sub2))
                        os.cp(f, dst_sub2)
                    end
                    end
                end
            end

            local lua_module = import("lua.module", {anonymous = true})
            local installdir = target:installdir()
            if not installdir then
                return
            end
            local name = target:name()
            local ver = "5.4"
            local lua_pkg = (target.pkg and (target:pkg("lua") or target:pkg("luajit"))) or nil
            if lua_pkg and lua_pkg.version then
                local s = tostring(lua_pkg:version()):gsub("^v", "")
                local major, minor = s:match("^(%d+)%.(%d+)")
                if major then
                    ver = major .. "." .. minor
                end
            end
            local record
            if target:data("forge.lua.is_pure") then
                local src
                for _, f in ipairs(table.wrap(target:sourcefiles())) do
                    if f:endswith(".lua") then
                        src = f
                        break
                    end
                end
                if src then
                    local rel = path.join("share/lua", ver, lua_module.module_lua_relpath(name, path.filename(src)))
                    rel = rel:gsub("\\", "/")
                    local dst = path.join(installdir, rel)
                    os.mkdir(path.directory(dst))
                    os.cp(src, dst)
                    record = {name = name, kind = "lua", relpath = rel}
                end
            elseif target:data("forge.lua.is_cmodule") then
                local symbol = "luaopen_" .. name:gsub("[^%w]", "_")
                local link = name:gsub("[^%w]", "_")
                record = {name = name, kind = "c", symbol = symbol, link = link}
                if target:data("forge.lua.is_static") then
                    local installed = path.join(target:libdir(), path.filename(target:targetfile()))
                    if os.isfile(installed) then
                        record.relpath = path.relative(installed, installdir):gsub("\\", "/")
                    end
                else
                    local installed = path.join(target:libdir(), path.filename(target:targetfile()))
                    local ext = path.extension(installed):gsub("^%.", "")
                    local rel = path.join("lib/lua", ver, lua_module.module_c_relpath(name, ext)):gsub("\\", "/")
                    local dst = path.join(installdir, rel)
                    if os.isfile(installed) then
                        os.mkdir(path.directory(dst))
                        os.cp(installed, dst)
                        if path.normalize(installed) ~= path.normalize(dst) then
                            os.rm(installed)
                        end
                        record.ext = ext
                        record.shared_relpath = rel
                        record.relpath = rel
                    end
                end
            end
            if record then
                local mdir = path.join(installdir, "share/forge")
                os.mkdir(mdir)
                local file = path.join(mdir, "lua-modules.lua")
                local data = os.isfile(file) and io.load(file) or {luaver = ver, modules = {}}
                if type(data) ~= "table" then
                    data = {luaver = ver, modules = {}}
                end
                data.luaver = data.luaver or ver
                data.modules = data.modules or {}
                local replaced = false
                for i, mod in ipairs(data.modules) do
                    if mod.name == record.name then
                        data.modules[i] = record
                        replaced = true
                    end
                end
                if not replaced then
                    table.insert(data.modules, record)
                end
                io.save(file, data)
                if lua_pkg and lua_pkg.installdir then
                    local root = lua_pkg:installdir()
                    local shared = lua_pkg.config and lua_pkg:config("shared") == true
                    if not shared then
                        shared = os.isfile(path.join(root, "lib", "liblua.so"))
                            or os.isfile(path.join(root, "lib", "liblua.dylib"))
                            or os.isfile(path.join(root, "bin", "lua.dll"))
                    end
                    io.save(path.join(mdir, "lua-runtime.lua"), {installdir = root, shared = shared})
                end
            end
            local search_ext = target:is_plat("windows", "mingw") and "dll" or "so"
            lua_module.write_module_search(installdir, search_ext)
        end)
end

setup_module_rule("forge.lua.module")

-- ==============================================================================
-- 2. Rule: forge.lua.bin
-- Install a Lua program into bin/. The script keeps its shebang. Unix marks it
-- executable. Windows also gets a .cmd launcher that calls lua.
-- ==============================================================================
rule("forge.lua.bin")
    set_extensions(".lua")

    on_load(function (target)
        target:set("kind", "phony")
        -- A program such as src/bin/luacov has no extension, so the file rule
        -- would otherwise reject it as an unknown source.
        for _, sourcefile in ipairs(table.wrap(target:get("files"))) do
            target:fileconfig_set(sourcefile, {rules = "forge.lua.bin"})
        end
    end)

    after_install(function (target)
        local installdir = target:installdir()
        if not installdir then
            return
        end
        local bindir = path.join(installdir, "bin")
        local root = os.projectdir()
        local seen = {}
        for _, sourcefile in ipairs(table.wrap(target:get("files"))) do
            local src = path.is_absolute(sourcefile) and sourcefile or path.join(root, sourcefile)
            if os.isfile(src) then
                local name = path.filename(src)
                if name:endswith(".lua") then
                    name = name:sub(1, -5)
                end
                if not seen[name] then
                    seen[name] = true
                    os.mkdir(bindir)
                    local dest = path.join(bindir, name)
                    os.cp(src, dest)
                    if target:is_plat("windows") then
                        io.writefile(dest .. ".cmd", "@echo off\r\nlua \"%~dp0\\" .. name .. "\" %*\r\n")
                    else
                        try { function () os.runv("chmod", {"+x", dest}) end }
                    end
                end
            end
        end
    end)

-- ==============================================================================
-- 3. Rule: forge.lua.app (alias: forge.lua.binary)
-- Lua Application runner, launcher generator, and direct CLI execution.
-- ==============================================================================
local function setup_app_rule(rule_name)
    rule(rule_name)
        set_extensions(".lua")

        on_load(function (target)
            import("lua.env")

            local is_bundle = target:values("forge.lua.bundle")
            if not is_bundle then
                target:set("kind", "phony")
            end

            -- Identify entry script
            local entry = target:values("forge.lua.entry") or target:values("forge.lua.main")
            if not entry then
                for _, f in ipairs(table.wrap(target:get("files"))) do
                    if f:endswith("main.lua") or f:endswith("cli.lua") or f:endswith("init.lua") or f:find("bin/", 1, true) then
                        entry = f
                        break
                    end
                end
                if not entry then
                    local files = table.wrap(target:get("files"))
                    if #files > 0 then
                        entry = files[1]
                    end
                end
            end
            target:data_set("forge.lua.entry", entry or "src/main.lua")

            -- Export environment paths
            target:add("runenvs", "LUA_PATH", env.get_lua_paths())
            target:add("runenvs", "LUA_CPATH", env.get_lua_cpaths())
        end)

        before_build(function (target)
            import("lua.env")
            env.stage_lua_sourcefiles(target, target:sourcefiles())
        end)

        after_build(function (target)
            local is_bundle = target:values("forge.lua.bundle")
            if is_bundle then
                return
            end

            local projdir = os.projectdir()
            local bindir = path.join(projdir, "build/bin")
            os.mkdir(bindir)

            import("lua.env")
            local lua_module = import("lua.module", {anonymous = true})
            local entry = target:data("forge.lua.entry") or "src/main.lua"
            local app_name = target:name()
            local roots, pkg_path, pkg_cpath = package_search(lua_module, target)
            local sandbox = lua_module.has_shared_native(roots)
            local lua_bin = env.lua_program(target) or "lua"
            local runtime_name = app_name .. ".runtime"
            local staged = nil
            if sandbox then
                staged = env.stage_sandbox(target, path.join(bindir, runtime_name), roots)
                lua_bin = path.join(bindir, runtime_name, "bin", (os.host() == "windows") and "lua.exe" or "lua")
            end

            if os.host() == "windows" then
                local cmd_file = path.join(bindir, app_name .. ".cmd")
                local path_extra = (#pkg_path > 0) and (pkg_path .. ";") or ""
                local cpath_extra = (#pkg_cpath > 0) and (pkg_cpath .. ";") or ""
                local content
                if sandbox then
                    content = {
                        "@echo off",
                        "rem Generated by Projectum Lunare Forge",
                        "set \"SELF_DIR=%~dp0\"",
                        "set \"RUNTIME=%SELF_DIR%" .. runtime_name .. "\"",
                        "pushd \"%SELF_DIR%..\\..\"",
                        "set \"PROJ_DIR=%CD%\"",
                        "popd",
                        "set \"LUA_PATH=%PROJ_DIR%\\src\\?.lua;%PROJ_DIR%\\src\\?\\init.lua;%PROJ_DIR%\\?.lua;%PROJ_DIR%\\?\\init.lua;" .. sandbox_patterns(staged, "%RUNTIME%", "path") .. "\"",
                        "set \"LUA_CPATH=" .. sandbox_patterns(staged, "%RUNTIME%", "cpath") .. "\"",
                        "\"%RUNTIME%\\bin\\lua.exe\" \"%PROJ_DIR%\\" .. entry:gsub("/", "\\") .. "\" %*"
                    }
                else
                    content = {
                    "@echo off",
                    "rem Generated by Projectum Lunare Forge",
                    "set \"SELF_DIR=%~dp0\"",
                    "pushd \"%SELF_DIR%..\\..\"",
                    "set \"PROJ_DIR=%CD%\"",
                    "popd",
                    "set \"LUA_PATH=%PROJ_DIR%\\build\\lua\\?.lua;%PROJ_DIR%\\build\\lua\\?\\init.lua;%PROJ_DIR%\\src\\?.lua;%PROJ_DIR%\\src\\?\\init.lua;" .. path_extra .. ";%LUA_PATH%\"",
                    "set \"LUA_CPATH=%PROJ_DIR%\\build\\lua\\?.dll;%PROJ_DIR%\\build\\lua\\?\\?.dll;" .. cpath_extra .. ";%LUA_CPATH%\"",
                    "if not defined LUA_BIN set LUA_BIN=" .. lua_bin,
                    "\"%LUA_BIN%\" \"%PROJ_DIR%\\" .. entry:gsub("/", "\\") .. "\" %*"
                    }
                end
                io.writefile(cmd_file, table.concat(content, "\r\n"))
            else
                local sh_file = path.join(bindir, app_name)
                local content
                if sandbox then
                    content = {
                        "#!/usr/bin/env sh",
                        "# Generated by Projectum Lunare Forge",
                        "SELF_DIR=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
                        "RUNTIME=\"$SELF_DIR/" .. runtime_name .. "\"",
                        "PROJ_DIR=\"$(cd \"$SELF_DIR/../..\" && pwd)\"",
                        "export LUA_PATH=\"$PROJ_DIR/src/?.lua;$PROJ_DIR/src/?/init.lua;$PROJ_DIR/?.lua;$PROJ_DIR/?/init.lua;" .. sandbox_patterns(staged, "$RUNTIME", "path") .. "\"",
                        "export LUA_CPATH=\"" .. sandbox_patterns(staged, "$RUNTIME", "cpath") .. "\""
                    }
                else
                    local path_extra = (#pkg_path > 0) and (pkg_path .. ";") or ""
                    local cpath_extra = (#pkg_cpath > 0) and (pkg_cpath .. ";") or ""
                    content = {
                        "#!/usr/bin/env sh",
                        "# Generated by Projectum Lunare Forge",
                        "SELF_DIR=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
                        "PROJ_DIR=\"$(cd \"$SELF_DIR/../..\" && pwd)\"",
                        "export LUA_PATH=\"$PROJ_DIR/build/lua/?.lua;$PROJ_DIR/build/lua/?/init.lua;$PROJ_DIR/src/?.lua;$PROJ_DIR/src/?/init.lua;" .. path_extra .. ";${LUA_PATH:+;$LUA_PATH}\"",
                        "export LUA_CPATH=\"$PROJ_DIR/build/lua/?.so;$PROJ_DIR/build/lua/?/?.so;$PROJ_DIR/build/lua/lib/?.so;" .. cpath_extra .. ";${LUA_CPATH:+;$LUA_CPATH}\""
                    }
                end
                if sandbox then
                    table.insert(content, "exec \"$RUNTIME/bin/lua\" \"$PROJ_DIR/" .. entry .. "\" \"$@\"")
                else
                    table.insert(content, "LUA_BIN=\"${LUA_BIN:-" .. lua_bin .. "}\"")
                    table.insert(content, "exec \"$LUA_BIN\" \"$PROJ_DIR/" .. entry .. "\" \"$@\"")
                end
                io.writefile(sh_file, table.concat(content, "\n"))
                try { function() os.runv("chmod", {"+x", sh_file}) end }
            end

            cprint("${bright green}==> [forge] Generated Lua launcher: ${bright white}%s${clear}", path.relative(path.join(bindir, app_name), projdir))
        end)

        on_run(function (target)
            import("core.base.option")
            import("lua.env")

            local lua_bin = env.lua_program(target)
            if not lua_bin then
                raise("Lua >= 5.4 was not found. Set LUA_BIN or add_requires(\"lua\").")
            end
            local entry = target:data("forge.lua.entry") or "src/main.lua"
            local entry_abs = path.is_absolute(entry) and entry or path.join(os.projectdir(), entry)

            if not os.isfile(entry_abs) then
                local staged = path.join(os.projectdir(), "build/lua", entry)
                if os.isfile(staged) then
                    entry_abs = staged
                end
            end

            if not os.isfile(entry_abs) then
                raise("Lua entrypoint not found: " .. entry)
            end

            local lua_module = import("lua.module", {anonymous = true})
            local roots = package_search(lua_module, target)
            local sandbox = lua_module.has_shared_native(roots)
            local args = option.get("arguments") or {}
            if sandbox then
                local launcher = path.join(os.projectdir(), "build/bin", target:name())
                if os.host() == "windows" then
                    launcher = launcher .. ".cmd"
                end
                if not os.isfile(launcher) then
                    raise("sandbox launcher missing: " .. launcher)
                end
                cprint("${dim}==> [forge] Executing sandbox launcher: %s${clear}", launcher)
                os.execv(launcher, args)
                return
            end
            local _, _, ver = env.get_lua_version(lua_bin)
            local envs = os.getenvs()
            local lua_env = env.get_env(os.projectdir(), {
                package_roots = roots,
                inherit_env = false,
                sandbox = false,
                ver = ver
            })
            envs.LUA_PATH = lua_env.LUA_PATH
            envs.LUA_CPATH = lua_env.LUA_CPATH
            local run_args = table.join({entry_abs}, args)

            cprint("${dim}==> [forge] Executing: %s %s${clear}", lua_bin, table.concat(run_args, " "))
            os.execv(lua_bin, run_args, {envs = envs})
        end)
end

setup_app_rule("forge.lua.app")
setup_app_rule("forge.lua.binary")

-- ==============================================================================
-- 4. Rule: forge.lua.bundle
-- Monolithic standalone C89 binary bundling Lua runtime and byte arrays.
-- ==============================================================================
local function setup_bundle_rule(rule_name)
    rule(rule_name)
        add_deps("c")
        set_extensions(".lua")

        on_load(function (target)
            target:set("kind", "binary")
            target:values_set("forge.lua.bundle", true)

            local has_lua = false
            for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                if pkg == "lua" or pkg == "luajit" then
                    has_lua = true
                    break
                end
            end
            if not has_lua then
                target:add("packages", "lua")
            end
            target:add("defines", "LUA_COMPAT_5_3")

            -- Math library (-lm) is only required/present on POSIX/Unix systems
            -- Do not link 'm' on DOS (Watcom), OS/2 (Watcom), Windows CE (eVC3), or native Windows
            if not target:is_plat("dos", "os2", "wince", "windows") then
                target:add("links", "m")
            end
        end)

        on_config(function (target)
            local lua_module = import("lua.module", {anonymous = true})
            local natives = lua_module.bundle_sources(lua_module.roots_of(target)).natives
            for _, native in ipairs(natives) do
                if native.link then
                    -- The module archive references liblua, so it has to be linked first.
                    target:add("links", native.link)
                    if native.linkdir then
                        target:add("linkdirs", native.linkdir)
                    end
                    target:add("linkorders", native.link, "lua")
                end
            end
        end)

        before_buildcmd_files(function (target, batchcmds, sourcebatch, opt)
            import("lua.bundler")
            import("lua.env")

            local lua_module = import("lua.module", {anonymous = true})
            local bundled = lua_module.bundle_sources(lua_module.roots_of(target))

            local luafiles = table.join(sourcebatch.sourcefiles, bundled.files)
            local file_map, module_map = env.get_file_map(target, sourcebatch.sourcefiles)
            for src, rel in pairs(bundled.file_map) do
                file_map[src] = rel
                module_map[src] = bundled.module_map[src]
            end

            -- Resolve entrypoint module name accurately preserving hierarchy
            local entry = target:values("forge.lua.entry") or target:values("forge.lua.main") or "main"
            local entry_mod
            if entry:endswith(".lua") or entry:find("[/\\]") then
                local entry_rel = env.get_relative_path(target, entry)
                entry_mod = env.get_module_name(entry_rel)
            else
                entry_mod = entry
            end

            local bundle_c = path.join(target:autogendir(), "bundle.c")

            local tmpl_file = target:values("forge.lua.template")
            if tmpl_file and not path.is_absolute(tmpl_file) then
                tmpl_file = path.join(os.projectdir(), tmpl_file)
            end

            local code = bundler.generate_bundle_source(luafiles, {
                projdir = os.projectdir(),
                file_map = file_map,
                module_map = module_map,
                entry_module = entry_mod,
                include_main = true,
                template_file = tmpl_file,
                native_modules = bundled.natives,
                cpath = bundled.cpath
            })

            io.writefile(bundle_c, code)

            local objfile = target:objectfile(bundle_c)
            table.insert(target:objectfiles(), objfile)

            batchcmds:mkdir(path.directory(bundle_c))
            batchcmds:mkdir(path.directory(objfile))
            batchcmds:show_progress(opt.progress, "${color.build.target}compiling.bundle %s", path.relative(bundle_c, os.projectdir()))
            batchcmds:compile(bundle_c, objfile)
            batchcmds:add_depfiles(luafiles)
            if tmpl_file and os.isfile(tmpl_file) then
                batchcmds:add_depfiles(tmpl_file)
            end
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)
end

setup_bundle_rule("forge.lua.bundle")
