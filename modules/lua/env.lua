-- Projectum Lunare Recudo - Lua Environment & Path Orchestration Module
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
    local rootdir = (target and target.extraconf and target:extraconf("files", srcfile, "rootdir")) or (target and target.values and target:values("recudo.lua.rootdir"))
    if rootdir then
        return path.relative(srcfile, rootdir):gsub("\\", "/")
    end

    local norm = path.normalize(srcfile):gsub("\\", "/")
    if norm:startswith("src/lua/") then
        return norm:sub(9)
    elseif norm:startswith("src/") then
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
    local tree = import("lua.tree", {anonymous = true})
    for _, pattern in ipairs(tree.search_patterns(roots, kind)) do
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
    local tree = import("lua.tree", {anonymous = true})
    local function from_pkg(pkg)
        if not pkg or not pkg.installdir then
            return nil
        end
        if is_lua_pkg(pkg) then
            return program_in(pkg)
        end
        local runtime = tree.load_runtime(pkg:installdir({readonly = true}))
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
    for _, root in ipairs(tree.roots_of(target)) do
        local runtime = tree.load_runtime(root)
        if runtime then
            local prog = program_in_dir(runtime.installdir)
            if prog then
                return prog
            end
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

    local tree = import("lua.tree", {anonymous = true})
    local luavers = {}
    local cexts = {}
    for _, root in ipairs(roots or {}) do
        local manifest = tree.load_manifest(root)
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

local LUA_FALLBACK_VER = "5.4"

local function lua_version(ver)
    if ver then
        return ver
    end
    local _, _, found = get_lua_version(find_lua())
    return found or LUA_FALLBACK_VER
end

-- A group lists fixed patterns first. Patterns that contain {ver} then follow
-- for the requested version, and again for 5.4 when that version differs.
local function search_list(root, groups, ver, ext)
    local items = {}
    local function emit(rel, version)
        rel = rel:gsub("{ver}", version or "")
        rel = rel:gsub("{ext}", ext or "")
        table.insert(items, path.join(root, rel))
    end
    for _, group in ipairs(groups) do
        local versioned = {}
        for _, rel in ipairs(group) do
            if rel:find("{ver}", 1, true) then
                table.insert(versioned, rel)
            else
                emit(rel)
            end
        end
        for _, rel in ipairs(versioned) do
            emit(rel, ver)
        end
        if #versioned > 0 and ver ~= LUA_FALLBACK_VER then
            for _, rel in ipairs(versioned) do
                emit(rel, LUA_FALLBACK_VER)
            end
        end
    end
    return items
end

local function finish_search(items, opt, kind, env_name)
    append_package_patterns(items, opt.package_roots, kind)
    local result = table.concat(items, ";")
    if not opt.sandbox then
        result = result .. ";;"
    end
    if not opt.sandbox and opt.inherit_env ~= false then
        local inherited = os.getenv(env_name)
        if inherited and #inherited > 0 then
            result = result .. ";" .. inherited
        end
    end
    return result
end

-- Project sources, then the staged tree, then vendored trees.
local PATH_GROUPS = {
    {
        "src/?.lua",
        "src/?/init.lua",
        "lua/?.lua",
        "lua/?/init.lua",
        "?.lua",
        "?/init.lua"
    },
    {
        "build/lua/?.lua",
        "build/lua/?/init.lua",
        "build/lua/share/?.lua",
        "build/lua/share/?/init.lua",
        "build/lua/share/lua/{ver}/?.lua",
        "build/lua/share/lua/{ver}/?/init.lua"
    },
    {
        "vendor/?.lua",
        "vendor/?/init.lua",
        "vendor/share/lua/{ver}/?.lua",
        "vendor/share/lua/{ver}/?/init.lua",
        "lua_modules/share/lua/{ver}/?.lua",
        "lua_modules/share/lua/{ver}/?/init.lua"
    }
}

local CPATH_GROUPS = {
    {
        "build/lua/?.{ext}",
        "build/lua/?/?.{ext}",
        "build/lua/lib/?.{ext}",
        "build/lua/lib/?/?.{ext}",
        "build/lua/lib/lua/{ver}/?.{ext}",
        "build/lua/lib/lua/{ver}/?/?.{ext}"
    },
    {
        "vendor/lib/lua/{ver}/?.{ext}",
        "vendor/lib/lua/{ver}/?/?.{ext}",
        "lua_modules/lib/lua/{ver}/?.{ext}",
        "lua_modules/lib/lua/{ver}/?/?.{ext}"
    }
}

-- Get canonical LUA_PATH string for a project
function get_lua_paths(projdir, ver, opt)
    ver, opt = normalize_path_opt(ver, opt)
    projdir = projdir or os.projectdir()
    ver = lua_version(ver)
    return finish_search(search_list(projdir, PATH_GROUPS, ver), opt, "path", "LUA_PATH")
end

-- Get canonical LUA_CPATH string for dynamic C extensions (.so / .dll)
function get_lua_cpaths(projdir, ver, opt)
    ver, opt = normalize_path_opt(ver, opt)
    projdir = projdir or os.projectdir()
    ver = lua_version(ver)
    local ext = (os.host() == "windows") and "dll" or "so"
    return finish_search(search_list(projdir, CPATH_GROUPS, ver, ext), opt, "cpath", "LUA_CPATH")
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
        "# Generated by Projectum Lunare Recudo",
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
                cprint("${dim}[recudo] Staged %s -> %s${clear}", path.relative(srcfile, projdir), relpath)
            end
        end
    end
end
