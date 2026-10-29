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
        return path.relative(srcfile, rootdir)
    end

    local norm = path.normalize(srcfile)
    if norm:startswith("src/") then
        return norm:sub(5)
    elseif norm:startswith("lua/") then
        return norm:sub(5)
    elseif norm:startswith("lib/") then
        return norm:sub(5)
    end

    return path.relative(srcfile, os.projectdir())
end

-- Resolve canonical Lua module name from a relative path
function get_module_name(relpath)
    local modname = relpath:gsub("%.lua$", ""):gsub("[/\\]", ".")
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

-- Get canonical LUA_PATH string for a project
function get_lua_paths(projdir, ver)
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

    -- 4. Join and append Lua system default fallback (;;)
    local path_str = table.concat(paths, ";") .. ";;"
    local user_lua_path = os.getenv("LUA_PATH")
    if user_lua_path and #user_lua_path > 0 then
        path_str = path_str .. ";" .. user_lua_path
    end

    return path_str
end

-- Get canonical LUA_CPATH string for dynamic C extensions (.so / .dll)
function get_lua_cpaths(projdir, ver)
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

    -- 3. Join and append Lua system default fallback (;;)
    local cpath_str = table.concat(cpaths, ";") .. ";;"
    local user_lua_cpath = os.getenv("LUA_CPATH")
    if user_lua_cpath and #user_lua_cpath > 0 then
        cpath_str = cpath_str .. ";" .. user_lua_cpath
    end

    return cpath_str
end

-- Returns environment table { LUA_PATH = ..., LUA_CPATH = ... }
function get_env(projdir)
    return {
        LUA_PATH  = get_lua_paths(projdir),
        LUA_CPATH = get_lua_cpaths(projdir)
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
