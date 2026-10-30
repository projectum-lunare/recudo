-- Projectum Lunare Forge - Lua Environment & Path Orchestration Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- Provides unified LUA_PATH and LUA_CPATH generation, robust cross-platform
-- Lua interpreter detection (>= 5.4), and .env file generation for IDEs, tools, and developer workflows.

import("core.base.option")

-- Extract major, minor, and version string from a Lua executable
function get_lua_version(prog)
    if not prog then return nil end
    local ver_str = try { function() return os.iorunv(prog, {"-v"}) end } or ""
    local major, minor = ver_str:match("Lua (%d+)%.(%d+)")
    if major and minor then
        return tonumber(major), tonumber(minor), string.format("%s.%s", major, minor)
    end
    return nil
end

-- Detect or find a valid Lua interpreter (>= 5.4) across Linux, macOS, and Windows
function find_lua(opt)
    opt = opt or {}
    local find_tool = import("lib.detect.find_tool")

    -- 1. Explicit override via opt or environment variable
    local user_lua = opt.interpreter or os.getenv("LUA_BIN") or os.getenv("LUA")
    if user_lua and #user_lua > 0 then
        local p = os.isexec(user_lua) and user_lua
        if not p then
            local tool = find_tool(user_lua)
            p = tool and tool.program
        end
        if p then
            local maj, min = get_lua_version(p)
            if maj and (maj > 5 or (maj == 5 and min >= 4)) then
                return p
            end
        end
    end

    -- 2. Priority candidate search for modern Lua versions (>= 5.4)
    local candidates = {"lua5.5", "lua5.4", "lua55", "lua54", "lua"}
    for _, name in ipairs(candidates) do
        local tool = find_tool(name)
        if tool and tool.program then
            local maj, min = get_lua_version(tool.program)
            if maj and (maj > 5 or (maj == 5 and min >= 4)) then
                return tool.program
            end
        end
    end

    return nil
end

-- Resolve source file relative path inside a target
function get_relative_path(target, srcfile)
    local rootdir = (target and target:extraconf("files", srcfile, "rootdir")) or (target and target:values("forge.lua.rootdir"))
    if rootdir then
        return path.relative(srcfile, rootdir):gsub("\\", "/")
    end

    local norm = path.normalize(srcfile):gsub("\\", "/")
    if norm:startswith("src/") then
        return norm:sub(5)
    elseif norm:startswith("lua/") then
        return norm:sub(5)
    elseif norm:startswith("lib/") then
        return norm:sub(5)
    end

    return path.relative(srcfile, os.projectdir()):gsub("\\", "/")
end

-- Resolve canonical Lua module name from a relative path
function get_module_name(relpath)
    if not relpath then return "main" end
    local clean = relpath:gsub("\\", "/")
    local modname = clean:gsub("%.lua$", ""):gsub("/", ".")
    if modname:endswith(".init") and #modname > 5 then
        modname = modname:sub(1, -6)
    end
    return modname
end

-- Build file_map for sourcefiles: { [srcfile] = relpath, ... } and module_map
function get_file_map(target, sourcefiles)
    local file_map = {}
    local module_map = {}
    for _, src in ipairs(table.wrap(sourcefiles)) do
        if src:endswith(".lua") then
            local rel = get_relative_path(target, src)
            file_map[src] = rel
            module_map[src] = get_module_name(rel)
        end
    end
    return file_map, module_map
end

local function normalize_path_opt(ver, opt)
    if type(ver) == "table" and opt == nil then
        opt = ver
        ver = nil
    end
    return ver, opt or {}
end

local function append_package_patterns(items, roots, kind)
    if not roots or #roots == 0 then
        return
    end
    local lua_package = import("lua.package", {alias = "lua_package"})
    for _, pattern in ipairs(lua_package.search_patterns(roots, kind)) do
        table.insert(items, pattern)
    end
end

local function program_in_dir(dir)
    if not dir or not os.isdir(dir) then
        return nil
    end
    for _, bin in ipairs({"lua", "lua.exe", "luajit", "luajit.exe"}) do
        local prog = path.join(dir, "bin", bin)
        if os.isexec(prog) then
            return prog
        end
    end
    return nil
end

local function program_in(pkg)
    if not pkg or not pkg.installdir then
        return nil
    end
    return program_in_dir(pkg:installdir({readonly = true}))
end

local function is_lua_pkg(pkg)
    if not pkg or not pkg.name then
        return false
    end
    local name = pkg:name()
    return name == "lua" or name == "luajit"
end

-- The xmake-built interpreter attached to this target, directly or through a C module recipe.
-- The recipe records package:dep("lua"):installdir() at install time.
function private_lua(target)
    if not target or not target.orderpkgs then
        return nil
    end
    local lua_package = import("lua.package", {alias = "lua_package"})
    local function from_pkg(pkg)
        if not pkg or not pkg.installdir then
            return nil
        end
        if is_lua_pkg(pkg) then
            return program_in(pkg)
        end
        local runtime = lua_package.load_runtime(pkg:installdir({readonly = true}))
        if runtime then
            return program_in_dir(runtime.installdir)
        end
        return nil
    end
    if target.pkg then
        for _, name in ipairs({"lua", "luajit"}) do
            local found = from_pkg(target:pkg(name))
            if found then
                return found
            end
        end
    end
    for _, pkg in ipairs(target:orderpkgs()) do
        local found = from_pkg(pkg)
        if found then
            return found
        end
    end
    return nil
end

local function copy_newer(src, dst)
    if not os.isfile(src) then
        return
    end
    if os.isfile(dst) and os.mtime(src) <= os.mtime(dst) then
        return
    end
    os.mkdir(path.directory(dst))
    os.cp(src, dst)
end

-- Copy the private interpreter, its liblua and the recipe modules next to the launcher.
-- bin/lua is a wrapper that points the dynamic loader at ../lib, so the tree can move
-- without LD_LIBRARY_PATH and without the xmake package cache.
function stage_sandbox(target, destdir, roots)
    local prog = private_lua(target)
    if not prog then
        raise("A C Lua module needs the private interpreter built with the lua package.")
    end
    local prefix = path.directory(path.directory(prog))
    local bindir = path.join(destdir, "bin")
    local libdir = path.join(destdir, "lib")
    os.mkdir(bindir)
    os.mkdir(libdir)

    local bin_name = path.filename(prog)
    if os.host() == "windows" then
        copy_newer(prog, path.join(bindir, bin_name))
    else
        copy_newer(prog, path.join(bindir, "lua.bin"))
        local wrapper = path.join(bindir, "lua")
        io.writefile(wrapper, table.concat({
            "#!/bin/sh",
            "SELF=$(cd \"$(dirname \"$0\")\" && pwd)",
            "export LD_LIBRARY_PATH=\"$SELF/../lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"",
            "export DYLD_LIBRARY_PATH=\"$SELF/../lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}\"",
            "exec \"$SELF/lua.bin\" \"$@\"",
            ""
        }, "\n"))
        try { function() os.runv("chmod", {"+x", wrapper}) end }
        try { function() os.runv("chmod", {"+x", path.join(bindir, "lua.bin")}) end }
    end

    local src_lib = path.join(prefix, "lib")
    local src_bin = path.join(prefix, "bin")
    if os.isdir(src_lib) then
        for _, f in ipairs(os.files(path.join(src_lib, "liblua.*"))) do
            copy_newer(f, path.join(libdir, path.filename(f)))
        end
        for _, f in ipairs(os.files(path.join(src_lib, "lua*.dll"))) do
            copy_newer(f, path.join(bindir, path.filename(f)))
        end
    end
    if os.isdir(src_bin) then
        for _, f in ipairs(os.files(path.join(src_bin, "lua*.dll"))) do
            copy_newer(f, path.join(bindir, path.filename(f)))
        end
    end

    local lua_package = import("lua.package", {alias = "lua_package"})
    local luavers = {}
    local cexts = {}
    for _, root in ipairs(roots or {}) do
        local manifest = lua_package.load_manifest(root)
        if manifest then
            if manifest.luaver then
                luavers[manifest.luaver] = true
            end
            for _, mod in ipairs(manifest.modules or {}) do
                if mod.kind == "lua" and mod.relpath then
                    copy_newer(path.join(root, mod.relpath), path.join(destdir, mod.relpath))
                elseif mod.shared_relpath then
                    copy_newer(path.join(root, mod.shared_relpath), path.join(destdir, mod.shared_relpath))
                    if mod.ext then
                        cexts[mod.ext] = true
                    end
                end
            end
        end
    end

    local versions = {}
    for ver, _ in pairs(luavers) do
        table.insert(versions, ver)
    end
    table.sort(versions)
    local exts = {}
    for ext, _ in pairs(cexts) do
        table.insert(exts, ext)
    end
    table.sort(exts)
    return {
        versions = versions,
        exts = exts
    }
end

-- Interpreter that matches the Lua package linked into this target.
-- Native modules are built against that library, so the runner uses the same binary.
function lua_program(target)
    return private_lua(target) or find_lua()
end

-- Library directory of the private Lua package, when it ships a shared library.
function lua_libdir(target)
    local prog = private_lua(target)
    if not prog then
        return nil
    end
    local dir = path.join(path.directory(path.directory(prog)), "lib")
    if os.isdir(dir) then
        return dir
    end
    return nil
end

-- Get canonical LUA_PATH string for a project
function get_lua_paths(projdir, ver, opt)
    ver, opt = normalize_path_opt(ver, opt)
    projdir = projdir or os.projectdir()
    if not ver then
        local lua_bin = find_lua()
        local _, _, vstr = get_lua_version(lua_bin)
        ver = vstr or "5.4"
    end

    local paths = {}

    -- 1. Project local source patterns (immediate loading in dev mode)
    table.insert(paths, path.join(projdir, "src/?.lua"))
    table.insert(paths, path.join(projdir, "src/?/init.lua"))
    table.insert(paths, path.join(projdir, "lua/?.lua"))
    table.insert(paths, path.join(projdir, "lua/?/init.lua"))
    table.insert(paths, path.join(projdir, "?.lua"))
    table.insert(paths, path.join(projdir, "?/init.lua"))

    -- 2. Staged build outputs (compiled / copied artifacts)
    table.insert(paths, path.join(projdir, "build/lua/?.lua"))
    table.insert(paths, path.join(projdir, "build/lua/?/init.lua"))
    table.insert(paths, path.join(projdir, "build/lua/share/?.lua"))
    table.insert(paths, path.join(projdir, "build/lua/share/?/init.lua"))
    table.insert(paths, path.join(projdir, "build/lua/share/lua", ver, "?.lua"))
    table.insert(paths, path.join(projdir, "build/lua/share/lua", ver, "?/init.lua"))
    if ver ~= "5.4" then
        table.insert(paths, path.join(projdir, "build/lua/share/lua/5.4/?.lua"))
        table.insert(paths, path.join(projdir, "build/lua/share/lua/5.4/?/init.lua"))
    end

    -- 3. Vendored and local dependencies (vendor / lua_modules)
    table.insert(paths, path.join(projdir, "vendor/?.lua"))
    table.insert(paths, path.join(projdir, "vendor/?/init.lua"))
    table.insert(paths, path.join(projdir, "vendor/share/lua", ver, "?.lua"))
    table.insert(paths, path.join(projdir, "vendor/share/lua", ver, "?/init.lua"))
    table.insert(paths, path.join(projdir, "lua_modules/share/lua", ver, "?.lua"))
    table.insert(paths, path.join(projdir, "lua_modules/share/lua", ver, "?/init.lua"))
    if ver ~= "5.4" then
        table.insert(paths, path.join(projdir, "vendor/share/lua/5.4/?.lua"))
        table.insert(paths, path.join(projdir, "vendor/share/lua/5.4/?/init.lua"))
        table.insert(paths, path.join(projdir, "lua_modules/share/lua/5.4/?.lua"))
        table.insert(paths, path.join(projdir, "lua_modules/share/lua/5.4/?/init.lua"))
    end

    -- 4. xmake packages installed by lua.package
    append_package_patterns(paths, opt.package_roots, "path")

    -- 5. A sandbox keeps only the project and its packages. `;;` would reopen the system path.
    local path_str = table.concat(paths, ";")
    if not opt.sandbox then
        path_str = path_str .. ";;"
    end
    if not opt.sandbox and opt.inherit_env ~= false then
        local user_lua_path = os.getenv("LUA_PATH")
        if user_lua_path and #user_lua_path > 0 then
            path_str = path_str .. ";" .. user_lua_path
        end
    end

    return path_str
end

-- Get canonical LUA_CPATH string for dynamic C extensions (.so / .dll)
function get_lua_cpaths(projdir, ver, opt)
    ver, opt = normalize_path_opt(ver, opt)
    projdir = projdir or os.projectdir()
    if not ver then
        local lua_bin = find_lua()
        local _, _, vstr = get_lua_version(lua_bin)
        ver = vstr or "5.4"
    end

    local cpaths = {}
    local ext = (os.host() == "windows") and "dll" or "so"

    -- 1. Project local build / staging directory
    table.insert(cpaths, path.join(projdir, "build/lua/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/?/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/?/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/lua", ver, "?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/lua", ver, "?/?." .. ext))
    if ver ~= "5.4" then
        table.insert(cpaths, path.join(projdir, "build/lua/lib/lua/5.4/?." .. ext))
        table.insert(cpaths, path.join(projdir, "build/lua/lib/lua/5.4/?/?." .. ext))
    end

    -- 2. Vendored C modules
    table.insert(cpaths, path.join(projdir, "vendor/lib/lua", ver, "?." .. ext))
    table.insert(cpaths, path.join(projdir, "vendor/lib/lua", ver, "?/?." .. ext))
    table.insert(cpaths, path.join(projdir, "lua_modules/lib/lua", ver, "?." .. ext))
    table.insert(cpaths, path.join(projdir, "lua_modules/lib/lua", ver, "?/?." .. ext))
    if ver ~= "5.4" then
        table.insert(cpaths, path.join(projdir, "vendor/lib/lua/5.4/?." .. ext))
        table.insert(cpaths, path.join(projdir, "vendor/lib/lua/5.4/?/?." .. ext))
        table.insert(cpaths, path.join(projdir, "lua_modules/lib/lua/5.4/?." .. ext))
        table.insert(cpaths, path.join(projdir, "lua_modules/lib/lua/5.4/?/?." .. ext))
    end

    -- 3. xmake packages installed by lua.package
    append_package_patterns(cpaths, opt.package_roots, "cpath")

    -- 4. A sandbox keeps only the project and its packages. `;;` would reopen the system path.
    local cpath_str = table.concat(cpaths, ";")
    if not opt.sandbox then
        cpath_str = cpath_str .. ";;"
    end
    if not opt.sandbox and opt.inherit_env ~= false then
        local user_lua_cpath = os.getenv("LUA_CPATH")
        if user_lua_cpath and #user_lua_cpath > 0 then
            cpath_str = cpath_str .. ";" .. user_lua_cpath
        end
    end

    return cpath_str
end

-- Returns environment table { LUA_PATH = ..., LUA_CPATH = ... }
function get_env(projdir, opt)
    opt = opt or {}
    local ver = opt.ver
    return {
        LUA_PATH  = get_lua_paths(projdir, ver, opt),
        LUA_CPATH = get_lua_cpaths(projdir, ver, opt)
    }
end

-- Export .env file for IDEs (VS Code, Neovim, LuaLS)
function write_dotenv(projdir, output_file)
    projdir = projdir or os.projectdir()
    output_file = output_file or path.join(projdir, ".env")
    local lines = {
        "# Generated by Projectum Lunare Forge",
        "LUA_PATH=\"" .. get_lua_paths(projdir) .. "\"",
        "LUA_CPATH=\"" .. get_lua_cpaths(projdir) .. "\"",
        ""
    }
    io.writefile(output_file, table.concat(lines, "\n"))
end

-- Stage Lua source files into build/lua
function stage_lua_sourcefiles(target, sourcefiles)
    local projdir = os.projectdir()
    local staging_dir = path.join(projdir, "build/lua")

    for _, srcfile in ipairs(table.wrap(sourcefiles)) do
        if srcfile:endswith(".lua") then
            local relpath = get_relative_path(target, srcfile)
            local dstfile = path.join(staging_dir, relpath)
            if not os.isfile(dstfile) or os.mtime(srcfile) > os.mtime(dstfile) then
                os.mkdir(path.directory(dstfile))
                os.cp(srcfile, dstfile)
                cprint("${dim}[forge] Staged %s -> %s${clear}", path.relative(srcfile, projdir), relpath)
            end
        end
    end
end
