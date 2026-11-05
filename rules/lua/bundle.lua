-- Projectum Lunare Recudo - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- ==============================================================================
-- 4. Rule: recudo.lua.bundle
-- Monolithic standalone C89 binary bundling Lua runtime and byte arrays.
-- ==============================================================================
local function setup_bundle_rule(rule_name)
    rule(rule_name)
        set_extensions(".lua")
        set_sourcekinds("cc")

        on_load(function (target)
            if not target:get("kind") or target:get("kind") == "phony" then
                target:set("kind", "binary")
            end
            target:values_set("recudo.lua.bundle", true)
            if not target:is_plat("wince", "dos", "os2") and not target:rule("c") then
                target:add("rules", "c")
            end

            local has_lua = false
            for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                if pkg == "lua" or pkg == "luajit" or pkg == "openresty-luajit" then
                    has_lua = true
                    break
                end
            end
            if not has_lua then
                local project = import("core.project.project", {anonymous = true})
                local reqs = project.required_packages and project.required_packages()
                if reqs and (reqs["luajit"] or reqs["openresty-luajit"]) then
                    if reqs["luajit"] then
                        target:add("packages", "luajit")
                    else
                        target:add("packages", "openresty-luajit")
                    end
                else
                    target:add("packages", "lua")
                end
            end
            target:add("defines", "LUA_COMPAT_5_3")

            -- Resolve runtime parser capability (default: true)
            local has_parser = target:values("recudo.lua.parser")
            if has_parser == nil and target.has_config and target:has_config("parser") then
                has_parser = target:config("parser")
            end
            if has_parser == nil then
                for _, def in ipairs(table.wrap(target:get("defines"))) do
                    if def == "LUA_NO_PARSER" then
                        has_parser = false
                        break
                    end
                end
            end
            if has_parser == nil then
                has_parser = true
            end
            target:values_set("recudo.lua.parser", has_parser)
            if not has_parser then
                target:add("defines", "LUA_NO_PARSER")
            end

            -- Math library (-lm) is only required/present on POSIX/Unix systems
            -- Do not link 'm' on DOS (Watcom), OS/2 (Watcom), Windows CE (eVC3), or native Windows
            -- Nor when target explicitly configures recudo.lua.libs without 'math' or excludes it
            local libs = target:values("recudo.lua.libs")
            local exclude = target:values("recudo.lua.libs.exclude")
            local has_math = true
            if libs then
                has_math = false
                for _, l in ipairs(table.wrap(libs)) do
                    if l == "math" then has_math = true; break end
                end
            end
            if exclude then
                for _, l in ipairs(table.wrap(exclude)) do
                    if l == "math" then has_math = false; break end
                end
            end
            if has_math and not target:is_plat("dos", "os2", "wince", "windows") then
                target:add("links", "m")
            end
        end)

        on_config(function (target)
            if target:values("recudo.lua.bundle.natives") == false then
                return
            end
            local lua_module = import("lua.module", {anonymous = true})
            local natives = lua_module.bundle_sources(lua_module.roots_of(target)).natives
            for _, native in ipairs(natives) do
                if native.link then
                    -- The module archive references liblua, so it has to be linked first.
                    target:add("links", native.link)
                    if native.linkdir then
                        target:add("linkdirs", native.linkdir)
                    end
                    local rt_pkg = target:pkg("luajit") and "luajit" or (target:pkg("openresty-luajit") and "openresty-luajit" or "lua")
                    target:add("linkorders", native.link, rt_pkg)
                end
            end
        end)

        before_buildcmd_files(function (target, batchcmds, sourcebatch, opt)
            import("lua.bundler")
            import("lua.env")

            local lua_module = import("lua.module", {anonymous = true})
            local bundled = lua_module.bundle_sources(lua_module.roots_of(target))

            local only_lua = {}
            for _, f in ipairs(sourcebatch.sourcefiles) do
                if f:endswith(".lua") then
                    table.insert(only_lua, f)
                end
            end

            local luafiles = table.join(only_lua, bundled.files)
            local file_map, module_map = env.get_file_map(target, only_lua)
            for src, rel in pairs(bundled.file_map) do
                file_map[src] = rel
                module_map[src] = bundled.module_map[src]
            end

            -- Resolve entrypoint module name accurately preserving hierarchy
            local entry = target:values("recudo.lua.entry") or "main"
            local entry_mod
            if entry:endswith(".lua") or entry:find("[/\\]") then
                local entry_rel = env.get_relative_path(target, entry)
                entry_mod = env.get_module_name(entry_rel)
            else
                entry_mod = entry
            end

            local bundle_c = path.join(target:autogendir(), "bundle.c")

            local tmpl_file = target:values("recudo.lua.template")
            if tmpl_file and not path.is_absolute(tmpl_file) then
                tmpl_file = path.join(os.projectdir(), tmpl_file)
            end

            local has_parser = target:values("recudo.lua.parser")
            if has_parser == nil then
                has_parser = true
            end

            local mode = target:values("recudo.lua.bundle.mode")
            if not mode and target:values("recudo.lua.bundle") == "bytecode" then
                mode = "bytecode"
            end
            if not mode then
                for _, def in ipairs(table.wrap(target:get("defines"))) do
                    if def == "LUA_NO_PARSER" then
                        mode = "bytecode"
                        break
                    end
                end
            end
            if not mode and not has_parser then
                mode = "bytecode"
            end

            local preload_fn = target:values("recudo.lua.bundle.preload")
            local strip = target:values("recudo.lua.bundle.strip")
            local endian = target:values("recudo.lua.bundle.endian")
            local bits = target:values("recudo.lua.bundle.bits")
            local state_init = target:values("recudo.lua.state_init")
            local lua_libs = target:values("recudo.lua.libs")
            local lua_libs_exclude = target:values("recudo.lua.libs.exclude")
            local inc_main = target:values("recudo.lua.bundle.main")
            if inc_main == nil then
                inc_main = not (target:is_static() or target:is_shared())
            end

            local use_natives = target:values("recudo.lua.bundle.natives")
            local natives = (use_natives ~= false) and bundled.natives or {}

            local code = bundler.generate_bundle_source(luafiles, {
                projdir = os.projectdir(),
                file_map = file_map,
                module_map = module_map,
                entry_module = entry_mod,
                include_main = inc_main,
                state_init = state_init,
                lua_libs = lua_libs,
                lua_libs_exclude = lua_libs_exclude,
                parser = has_parser,
                no_parser = (has_parser == false),
                template_file = tmpl_file,
                native_modules = natives,
                cpath = bundled.cpath,
                target = target,
                mode = mode,
                endian = endian,
                bits = bits,
                strip = strip,
                preload_function = preload_fn
            })

            io.writefile(bundle_c, code)

            local objfile = target:objectfile(bundle_c)
            local cc = try { function() return target:tool("cc") end }
            if cc then
                if not table.contains(target:objectfiles(), objfile) then
                    table.insert(target:objectfiles(), objfile)
                end
                batchcmds:mkdir(path.directory(bundle_c))
                batchcmds:mkdir(path.directory(objfile))
                batchcmds:show_progress(opt.progress, "${color.build.target}compiling.bundle %s", path.relative(bundle_c, os.projectdir()))
                batchcmds:compile(bundle_c, objfile)
            else
                local handled = false
                for name, r in pairs(target:rules()) do
                    local fn = r and (r:script("buildcmd_file") or (r.buildcmd_file and r:buildcmd_file()))
                    if fn then
                        fn(target, batchcmds, bundle_c, opt)
                        handled = true
                        break
                    end
                end
                if not handled then
                    table.insert(target:objectfiles(), objfile)
                    batchcmds:compile(bundle_c, objfile)
                end
            end
            batchcmds:add_depfiles(luafiles)
            if tmpl_file and os.isfile(tmpl_file) then
                batchcmds:add_depfiles(tmpl_file)
            end
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)
end

setup_bundle_rule("recudo.lua.bundle")

