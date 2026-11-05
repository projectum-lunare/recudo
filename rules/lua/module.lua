-- Projectum Lunare Recudo - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- ==============================================================================
-- 1. Rule: recudo.lua.module
-- Supports pure Lua modules, C native modules (.so/.dll), and hybrid modules.
-- ==============================================================================
local function setup_module_rule(rule_name)
    rule(rule_name)
        set_extensions(".lua")
        local p = (is_plat and (is_plat("wince") and "wince" or (is_plat("dos") and "dos" or (is_plat("os2") and "os2")))) or (get_config and get_config("plat"))
        if p == "wince" then
            add_deps("recudo.evc3")
        elseif p == "dos" or p == "os2" then
            add_deps("recudo.watcom")
        end

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
                target:data_set("recudo.lua.is_cmodule", true)

                -- Project --kind selects static or shared. Platforms that cannot
                -- dlopen stay static. An explicit recudo.lua.kind can narrow one target.
                local lua_module = import("lua.module", {anonymous = true})
                import("core.project.config")
                local marked_shared = (config.get("kind") == "shared") or (target:get("kind") == "shared")
                local user_kind = target:values("recudo.lua.kind")
                if user_kind == "static" then
                    -- Embedding archive: always static, even in shared mode.
                    marked_shared = false
                end
                -- user_kind == "shared" declares loadable-module intent; the
                -- concrete artifact follows the global link mode: shared mode
                -- yields a .so linked against the runtime, static mode yields
                -- a binding archive without any embedded interpreter.
                local is_static = not lua_module.supports_dynamic(target:plat()) or not marked_shared

                if is_static then
                    -- Static archive mode (.a / .lib)
                    target:set("kind", "static")
                    target:data_set("recudo.lua.is_static", true)
                    target:data_set("recudo.lua.open_symbol", lua_module.open_symbol(target:name()))
                    if user_kind == "static" then
                        -- Explicit embedding archive: the project names and
                        -- places it (no suffix, no directory redirect).
                        local clean_name = target:get("basename") or lua_module.link_name(target:name())
                        target:set("basename", clean_name)
                    else
                        -- Implicit binding archives carry a _lua suffix so they
                        -- can never collide with the project's own C libraries
                        -- sharing the flattened module name (libcais_serial.a =
                        -- C subsystem vs libcais_serial_lua.a = Lua binding).
                        target:set("basename", lua_module.link_name(target:name()) .. "_lua")
                        local parts = target:name():split('.', {plain = true})
                        local subdirs = #parts > 1 and table.concat(table.slice(parts, 1, #parts - 1), "/") or ""
                        target:set("targetdir", path.join("build/lua_static", subdirs))
                    end
                    if lua_module.supports_dynamic(target:plat()) and not target:is_plat("windows") then
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
                        local exp_symbol = lua_module.open_symbol(target:name())
                        target:add("shflags", "/export:" .. exp_symbol, {force = true})
                    else
                        target:set("extension", ".so")
                        target:add("cxflags", "-fPIC")
                    end

                    -- recudo.lua.module targets are C by contract: xmake's
                    -- default shared linker is g++, whose driver spec records
                    -- libstdc++ as NEEDED even for pure C objects. Link with
                    -- the C driver on gcc/clang hosts instead.
                    if target:is_plat("linux", "macosx", "bsd") then
                        target:set("toolchains", "recudo-c")
                    end
                end

                -- Ensure Lua headers and defines for C modules
                local has_lua_pkg = false
                for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                    if pkg == "lua" or pkg == "luajit" or pkg == "openresty-luajit" then
                        has_lua_pkg = true
                        break
                    end
                end
                if not has_lua_pkg then
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
                if target:is_plat("wince") then
                    target:add("rules", "recudo.evc3", {override = true})
                elseif target:is_plat("dos", "os2") then
                    target:add("rules", "recudo.watcom", {override = true})
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
                target:data_set("recudo.lua.is_pure", true)
            end

            -- Automatically export canonical environment paths to target runtime
            target:add("runenvs", "LUA_PATH", env.get_lua_paths())
            target:add("runenvs", "LUA_CPATH", env.get_lua_cpaths())
        end)

        on_config(function (target)
            if target:data("recudo.lua.is_cmodule") then
                local lua_pkg = target:pkg("lua") or target:pkg("luajit") or target:pkg("openresty-luajit")
                if lua_pkg then
                    local dirs = table.join(table.wrap(lua_pkg:get("sysincludedirs")), table.wrap(lua_pkg:get("includedirs")))
                    for _, inc in ipairs(dirs) do
                        target:add("includedirs", inc)
                        for _, sub in ipairs({"lua", "luajit", "luajit-2.1", "luajit-2.0"}) do
                            local subinc = path.join(inc, sub)
                            if os.isdir(subinc) then
                                target:add("includedirs", subinc)
                            end
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
                    local parent = target:values("recudo.lua.parent_module") or target:data("recudo.lua.parent_module")
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
            local lua_pkg = (target.pkg and (target:pkg("lua") or target:pkg("luajit") or target:pkg("openresty-luajit"))) or nil
            if lua_pkg then
                if lua_pkg:name() == "luajit" or lua_pkg:name() == "openresty-luajit" then
                    ver = "5.1"
                elseif lua_pkg.version then
                    local parsed = lua_module.lua_version_string(lua_pkg:version())
                    if parsed then
                        ver = parsed
                    end
                end
            end
            local record
            if target:data("recudo.lua.is_pure") then
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
            elseif target:data("recudo.lua.is_cmodule") then
                local symbol = lua_module.open_symbol(name)
                local link = lua_module.link_name(name)
                record = {name = name, kind = "c", symbol = symbol, link = link}
                if target:data("recudo.lua.is_static") then
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
                        record.ext = ext
                        record.shared_relpath = rel
                        record.relpath = rel
                    end
                end
            end
            if record then
                lua_module.upsert_record(installdir, record, ver)
                if lua_pkg and lua_pkg.installdir then
                    local root = lua_pkg:installdir()
                    local shared = lua_pkg.config and lua_pkg:config("shared") == true
                    if not shared then
                        shared = lua_module.library_is_shared(root)
                    end
                    lua_module.save_runtime(installdir, root, shared)
                end
            end
            local search_ext = target:is_plat("windows", "mingw") and "dll" or "so"
            lua_module.write_module_search(installdir, search_ext)
        end)
end

setup_module_rule("recudo.lua.module")

