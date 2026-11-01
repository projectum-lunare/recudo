-- Projectum Lunare Forge - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

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

            local luafiles = table.join(sourcebatch.sourcefiles, bundled.files)
            local file_map, module_map = env.get_file_map(target, sourcebatch.sourcefiles)
            for src, rel in pairs(bundled.file_map) do
                file_map[src] = rel
                module_map[src] = bundled.module_map[src]
            end

            -- Resolve entrypoint module name accurately preserving hierarchy
            local entry = target:values("forge.lua.entry") or "main"
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

