-- Projectum Lunare Recudo - Lua C-Library Build Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- Rule: recudo.lua.clib
-- Transforms a collection of Lua source files into a native C static or shared library,
-- generating standard ANSI C headers and C ABI bridge glue code automatically.

local function setup_clib_rule(rule_name)
    rule(rule_name)
        set_extensions(".lua")
        set_sourcekinds("cc")

        on_load(function (target)
            if not target:get("kind") or target:get("kind") == "phony" or target:get("kind") == "binary" then
                target:set("kind", "static")
            end

            target:values_set("recudo.lua.clib", true)
            target:values_set("recudo.lua.bundle", true)
            target:values_set("recudo.lua.bundle.main", false)

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

            -- Prefix
            local prefix = target:values("recudo.lua.clib.prefix")
            if not prefix then
                prefix = target:basename() .. "_"
                target:values_set("recudo.lua.clib.prefix", prefix)
            end

            -- Register header directory as public includedir so dependent targets can find it
            local header_file = target:values("recudo.lua.clib.header")
            local header_path
            if header_file then
                header_path = path.is_absolute(header_file) and header_file or path.join(os.projectdir(), header_file)
            else
                header_file = prefix:gsub("_$", "") .. ".h"
                header_path = path.join(target:autogendir(), "include", header_file)
            end
            local header_dir = path.directory(header_path)
            target:add("includedirs", header_dir, {public = true})

            -- Math library linkage
            if not target:is_plat("dos", "os2", "wince", "windows") then
                target:add("links", "m")
            end
        end)

        on_config(function (target)
            import("lua.clib_generator")

            local prefix = target:values("recudo.lua.clib.prefix") or (target:basename() .. "_")
            local prefix_upper = prefix:upper():gsub("[^%w_]", "_")
            local api_macro = target:values("recudo.lua.clib.api_macro") or (prefix_upper .. "API")
            local entry = target:values("recudo.lua.clib.entry") or target:values("recudo.lua.entry") or "init"
            local mode = target:values("recudo.lua.clib.mode") or "context"
            local preload_fn = target:values("recudo.lua.bundle.preload") or (prefix .. "preload_bundled_modules")
            local exports = target:values("recudo.lua.clib.exports") or {}
            local lua_libs = target:values("recudo.lua.libs") or target:values("recudo.lua.clib.libs")
            local lua_libs_exclude = target:values("recudo.lua.libs.exclude") or target:values("recudo.lua.clib.libs.exclude")

            local header_file = target:values("recudo.lua.clib.header")
            local header_path
            if header_file then
                header_path = path.is_absolute(header_file) and header_file or path.join(os.projectdir(), header_file)
            else
                header_file = prefix:gsub("_$", "") .. ".h"
                header_path = path.join(target:autogendir(), "include", header_file)
            end

            local config = {
                prefix = prefix,
                api_macro = api_macro,
                mode = mode,
                entry_module = entry,
                preload_function = preload_fn,
                header_file = header_file,
                lua_libs = lua_libs,
                lua_libs_exclude = lua_libs_exclude,
                exports = exports
            }

            local header_code = clib_generator.generate_header(config)
            os.mkdir(path.directory(header_path))
            io.writefile(header_path, header_code)

            -- Generate C bridge source and register it as target C file
            local bridge_code = clib_generator.generate_bridge(config)
            local bridge_c = path.join(target:autogendir(), "bridge.c")
            os.mkdir(target:autogendir())
            io.writefile(bridge_c, bridge_code)
            target:add("files", bridge_c)
        end)

        before_buildcmd_files(function (target, batchcmds, sourcebatch, opt)
            import("lua.bundler")
            import("lua.clib_generator")
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

            local prefix = target:values("recudo.lua.clib.prefix") or (target:basename() .. "_")
            local prefix_upper = prefix:upper():gsub("[^%w_]", "_")
            local api_macro = target:values("recudo.lua.clib.api_macro") or (prefix_upper .. "API")

            local entry = target:values("recudo.lua.clib.entry") or target:values("recudo.lua.entry") or "init"
            local entry_mod
            if entry:endswith(".lua") or entry:find("[/\\]") then
                local entry_rel = env.get_relative_path(target, entry)
                entry_mod = env.get_module_name(entry_rel)
            else
                entry_mod = entry
            end

            local mode = target:values("recudo.lua.clib.mode") or "context"
            local preload_fn = target:values("recudo.lua.bundle.preload") or (prefix .. "preload_bundled_modules")
            local exports = target:values("recudo.lua.clib.exports") or {}
            local lua_libs = target:values("recudo.lua.libs") or target:values("recudo.lua.clib.libs")
            local lua_libs_exclude = target:values("recudo.lua.libs.exclude") or target:values("recudo.lua.clib.libs.exclude")

            -- Header destination
            local header_file = target:values("recudo.lua.clib.header")
            local header_path
            if header_file then
                header_path = path.is_absolute(header_file) and header_file or path.join(os.projectdir(), header_file)
            else
                header_file = prefix:gsub("_$", "") .. ".h"
                header_path = path.join(target:autogendir(), "include", header_file)
            end

            local header_dir = path.directory(header_path)
            target:add("includedirs", header_dir, {public = true})

            local config = {
                prefix = prefix,
                api_macro = api_macro,
                mode = mode,
                entry_module = entry_mod,
                preload_function = preload_fn,
                header_file = header_file,
                lua_libs = lua_libs,
                lua_libs_exclude = lua_libs_exclude,
                exports = exports
            }

            -- 1. Generate public C header
            local header_code = clib_generator.generate_header(config)
            os.mkdir(header_dir)
            io.writefile(header_path, header_code)

            -- 2. Compile Lua bundle source
            local bundle_mode = target:values("recudo.lua.bundle.mode") or "bytecode"
            local endian = target:values("recudo.lua.bundle.endian")
            local bits = target:values("recudo.lua.bundle.bits")
            local strip = target:values("recudo.lua.bundle.strip")

            local bundle_code = bundler.generate_bundle_source(luafiles, {
                projdir = os.projectdir(),
                file_map = file_map,
                module_map = module_map,
                entry_module = entry_mod,
                include_main = false,
                parser = false,
                no_parser = true,
                target = target,
                mode = bundle_mode,
                endian = endian,
                bits = bits,
                strip = strip,
                preload_function = preload_fn
            })

            local bundle_c = path.join(target:autogendir(), "bundle.c")
            io.writefile(bundle_c, bundle_code)

            local objfile = target:objectfile(bundle_c)
            if not table.contains(target:objectfiles(), objfile) then
                table.insert(target:objectfiles(), objfile)
            end
            batchcmds:mkdir(path.directory(bundle_c))
            batchcmds:mkdir(path.directory(objfile))
            batchcmds:show_progress(opt.progress, "${color.build.target}compiling.clib %s", path.relative(bundle_c, os.projectdir()))
            batchcmds:compile(bundle_c, objfile)
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))

            batchcmds:add_depfiles(luafiles)
        end)
end

setup_clib_rule("recudo.lua.clib")
setup_clib_rule("recudo.clib")
