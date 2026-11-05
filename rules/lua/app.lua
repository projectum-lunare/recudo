-- Projectum Lunare Recudo - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

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
-- 3. Rule: recudo.lua.app (alias: recudo.lua.binary)
-- Lua Application runner, launcher generator, and direct CLI execution.
-- ==============================================================================
local function setup_app_rule(rule_name)
    rule(rule_name)
        set_extensions(".lua")

        on_load(function (target)
            import("lua.env")

            target:data_set("recudo.lua.is_app", true)
            local is_bundle = target:values("recudo.lua.bundle")
            if not is_bundle then
                target:set("kind", "phony")
            end

            -- Identify entry script
            local entry = target:values("recudo.lua.entry")
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
                        if not entry:endswith(".lua") then
                            local base_name = target:basename() or target:name() or "main"
                            entry = "build/lua/" .. base_name .. ".lua"
                        end
                    end
                end
            end
            target:data_set("recudo.lua.entry", entry or "src/main.lua")

            -- Export environment paths
            target:add("runenvs", "LUA_PATH", env.get_lua_paths())
            target:add("runenvs", "LUA_CPATH", env.get_lua_cpaths())
        end)

        after_load(function (target)
            -- Static module dependencies cannot be dlopened: promote the app
            -- to a self-contained binary linking the binding archives, with
            -- the interpreter and the entry script embedded. Decided from
            -- values and configuration (pure computation) so the kind flip
            -- happens before xmake classifies the target for build.
            local static_modules = {}
            local lua_module = import("lua.module", {anonymous = true})
            local config = import("core.project.config", {anonymous = true})
            for _, depname in ipairs(table.wrap(target:get("deps"))) do
                local dept = target:dep(depname)
                if dept and dept:rule("recudo.lua.module") then
                    local user_kind = dept:values("recudo.lua.kind")
                    local dep_static = user_kind == "static"
                        or not lua_module.supports_dynamic(dept:plat())
                        or config.get("kind") ~= "shared"
                    if dep_static then
                        table.insert(static_modules, {
                            name = depname,
                            symbol = lua_module.open_symbol(depname)
                        })
                    end
                end
            end
            if #static_modules > 0 then
                local bundler = import("lua.bundler")
                local env_mod = import("lua.env")
                local projdir = os.projectdir()
                local entry = target:data("recudo.lua.entry") or "src/main.lua"
                local entry_abs = path.join(projdir, entry)
                if os.isfile(entry_abs) then
                    local gensrc = path.join(projdir, "build", ".recudo", target:name() .. "_bundle.c")
                    local src = bundler.generate_bundle_source({entry_abs}, {
                        entry_module = env_mod.get_module_name(entry),
                        native_modules = static_modules
                    })
                    os.mkdir(path.directory(gensrc))
                    io.writefile(gensrc, src)

                    target:set("kind", "binary")
                    target:set("targetdir", path.join(projdir, "build", "bin"))
                    target:add("files", gensrc)
                    target:add("packages", "lua")
                    -- Mirror the Lua ABI defines from the binding archives so
                    -- the embedded interpreter headers match the linked code
                    -- exactly (e.g. LUA_32BITS on 32-bit-ish targets).
                    for _, def in ipairs(table.wrap(target:dep(static_modules[1].name):get("defines"))) do
                        if def:startswith("LUA_") then
                            target:add("defines", def)
                        end
                    end
                    target:data_set("recudo.lua.static_app", true)
                end
            end
        end)

        before_build(function (target)
            import("lua.env")
            env.stage_lua_sourcefiles(target, target:sourcefiles())
        end)

        on_config(function (target)
            -- The promoted static app is C by construction: xmake's default
            -- binary linker is g++ (its driver spec records libstdc++ as
            -- NEEDED even for pure C objects). Link with the C driver on
            -- gcc/clang hosts instead. Happens here because the promotion
            -- itself runs in after_load.
            if target:data("recudo.lua.static_app") and target:is_plat("linux", "macosx", "bsd") then
                target:set("toolchains", "recudo-c")
            end
        end)

        after_build(function (target)
            local is_bundle = target:values("recudo.lua.bundle")
            if is_bundle or target:data("recudo.lua.static_app") then
                return
            end

            local projdir = os.projectdir()
            local bindir = path.join(projdir, "build/bin")
            os.mkdir(bindir)

            import("lua.env")
            local lua_module = import("lua.module", {anonymous = true})
            local entry = target:data("recudo.lua.entry") or "src/main.lua"
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
                        "rem Generated by Projectum Lunare Recudo",
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
                    "rem Generated by Projectum Lunare Recudo",
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
                        "# Generated by Projectum Lunare Recudo",
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
                        "# Generated by Projectum Lunare Recudo",
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

            cprint("${bright green}==> [recudo] Generated Lua launcher: ${bright white}%s${clear}", path.relative(path.join(bindir, app_name), projdir))
        end)

        on_run(function (target)
            import("core.base.option")
            import("lua.env")

            if target:data("recudo.lua.static_app") then
                local args = option.get("arguments") or {}
                cprint("${dim}==> [recudo] Executing static application: %s${clear}", target:targetfile())
                os.execv(target:targetfile(), args, {curdir = os.projectdir()})
                return
            end

            local lua_bin = env.lua_program(target)
            if not lua_bin then
                raise("Lua >= 5.4 was not found. Set LUA_BIN or add_requires(\"lua\").")
            end
            local entry = target:data("recudo.lua.entry") or "src/main.lua"
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
                cprint("${dim}==> [recudo] Executing sandbox launcher: %s${clear}", launcher)
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

            cprint("${dim}==> [recudo] Executing: %s %s${clear}", lua_bin, table.concat(run_args, " "))
            os.execv(lua_bin, run_args, {envs = envs})
        end)
end

setup_app_rule("recudo.lua.app")
setup_app_rule("recudo.lua.binary")

