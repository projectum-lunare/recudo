-- Projectum Lunare Forge - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- First-class Lua package management, module compilation, path orchestration
-- and application bundling for modern POSIX, Windows, and vintage targets.

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

                -- Determine static vs shared mode:
                -- 1. Explicit user choice: set_kind("static"/"shared") or set_values("forge.lua.kind", "static"/"shared")
                -- 2. Retro platform default: static
                -- 3. Modern desktop default: shared
                local user_kind = target:values("forge.lua.kind") or target:get("kind")
                local is_static = false

                if user_kind == "static" or target:values("forge.lua.static") then
                    is_static = true
                elseif user_kind == "shared" then
                    is_static = false
                elseif target:is_plat("amiga", "atari", "kolibri", "dos", "os2", "wince") then
                    is_static = true
                else
                    is_static = false
                end

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
            local staging_dir = path.join(os.projectdir(), "build/lua")
            if os.isdir(staging_dir) then
                local luafiles = os.files(path.join(staging_dir, "**.lua"))
                for _, f in ipairs(luafiles) do
                    local rel = path.relative(f, staging_dir)
                    -- Canonical installation: share/lua/
                    local dst1 = path.join(target:installdir(), "share/lua", rel)
                    os.mkdir(path.directory(dst1))
                    os.cp(f, dst1)

                    -- Flat installation: lib/
                    local dst2 = path.join(target:installdir(), "lib", rel)
                    os.mkdir(path.directory(dst2))
                    os.cp(f, dst2)

                    -- Namespaced mirror (e.g. lpeg/re.lua)
                    local parent = target:data("forge.lua.parent_module") or (target:name() == "re" and "lpeg" or nil)
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

            -- Ensure flat header mirror in include/ alongside namespaced headers
            if target:data("forge.lua.is_cmodule") then
                local headerfiles = target:get("headerfiles")
                if headerfiles then
                    for _, h in ipairs(table.wrap(headerfiles)) do
                        if os.isfile(h) then
                            os.mkdir(path.join(target:installdir(), "include"))
                            os.cp(h, path.join(target:installdir(), "include", path.filename(h)))
                        end
                    end
                end
            end
        end)
end

setup_module_rule("forge.lua.module")
setup_module_rule("vintage.lua.module")

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

            local entry = target:data("forge.lua.entry") or "src/main.lua"
            local app_name = target:name()

            if os.host() == "windows" then
                local cmd_file = path.join(bindir, app_name .. ".cmd")
                local content = {
                    "@echo off",
                    "rem Generated by Projectum Lunare Forge",
                    "set \"SELF_DIR=%~dp0\"",
                    "pushd \"%SELF_DIR%..\\..\"",
                    "set \"PROJ_DIR=%CD%\"",
                    "popd",
                    "set \"LUA_PATH=%PROJ_DIR%\\build\\lua\\?.lua;%PROJ_DIR%\\build\\lua\\?\\init.lua;%PROJ_DIR%\\src\\?.lua;%PROJ_DIR%\\src\\?\\init.lua;;%LUA_PATH%\"",
                    "set \"LUA_CPATH=%PROJ_DIR%\\build\\lua\\?.dll;%PROJ_DIR%\\build\\lua\\?\\?.dll;;%LUA_CPATH%\"",
                    "if not defined LUA_BIN set LUA_BIN=lua",
                    "\"%LUA_BIN%\" \"%PROJ_DIR%\\" .. entry:gsub("/", "\\") .. "\" %*"
                }
                io.writefile(cmd_file, table.concat(content, "\r\n"))
            else
                local sh_file = path.join(bindir, app_name)
                local content = {
                    "#!/usr/bin/env sh",
                    "# Generated by Projectum Lunare Forge",
                    "SELF_DIR=\"$(cd \"$(dirname \"$0\")\" && pwd)\"",
                    "PROJ_DIR=\"$(cd \"$SELF_DIR/../..\" && pwd)\"",
                    "export LUA_PATH=\"$PROJ_DIR/build/lua/?.lua;$PROJ_DIR/build/lua/?/init.lua;$PROJ_DIR/src/?.lua;$PROJ_DIR/src/?/init.lua;;${LUA_PATH:+;$LUA_PATH}\"",
                    "export LUA_CPATH=\"$PROJ_DIR/build/lua/?.so;$PROJ_DIR/build/lua/?/?.so;$PROJ_DIR/build/lua/lib/?.so;;${LUA_CPATH:+;$LUA_CPATH}\"",
                    "LUA_BIN=\"${LUA_BIN:-lua}\"",
                    "exec \"$LUA_BIN\" \"$PROJ_DIR/" .. entry .. "\" \"$@\""
                }
                io.writefile(sh_file, table.concat(content, "\n"))
                try { function() os.runv("chmod", {"+x", sh_file}) end }
            end

            cprint("${bright green}==> [forge] Generated Lua launcher: ${bright white}%s${clear}", path.relative(path.join(bindir, app_name), projdir))
        end)

        on_run(function (target)
            import("core.base.option")
            import("lua.env")

            local lua_bin = env.find_lua()
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

            local envs = env.get_env(os.projectdir())
            local args = option.get("arguments") or {}
            local run_args = table.join({entry_abs}, args)

            cprint("${dim}==> [forge] Executing: %s %s${clear}", lua_bin, table.concat(run_args, " "))
            os.execv(lua_bin, run_args, {envs = envs})
        end)
end

setup_app_rule("forge.lua.app")
setup_app_rule("forge.lua.binary")
setup_app_rule("vintage.lua.app")

-- ==============================================================================
-- 4. Rule: forge.lua.bundle
-- Monolithic standalone C89 binary bundling Lua runtime and byte arrays.
-- ==============================================================================
rule("forge.lua.bundle")
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
        target:add("links", "m")
    end)

    before_buildcmd_files(function (target, batchcmds, sourcebatch, opt)
        import("lua.bundler")

        local luafiles = sourcebatch.sourcefiles
        local entry = target:values("forge.lua.entry") or "main"
        local entry_mod = path.filename(entry):gsub("%.lua$", "")
        local bundle_c = path.join(target:autogendir(), "bundle.c")

        local tmpl_file = target:values("forge.lua.template")
        if tmpl_file and not path.is_absolute(tmpl_file) then
            tmpl_file = path.join(os.projectdir(), tmpl_file)
        end

        local code = bundler.generate_bundle_source(luafiles, {
            projdir = os.projectdir(),
            entry_module = entry_mod,
            include_main = true,
            template_file = tmpl_file
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
