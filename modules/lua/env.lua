-- Projectum Lunare Forge - Lua Environment & Path Orchestration Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- Provides unified LUA_PATH and LUA_CPATH generation, Lua interpreter detection (>= 5.4),
-- and .env file generation for IDEs, tools, and developer workflows.

import("core.base.option")

-- Detect or find a valid Lua interpreter (>= 5.4)
function find_lua(opt)
    opt = opt or {}

    -- 1. Explicit override via opt or environment variable
    local user_lua = opt.interpreter or os.getenv("LUA_BIN") or os.getenv("LUA")
    if user_lua and #user_lua > 0 then
        local p = os.isexec(user_lua) and user_lua or os.iorunv("which", {user_lua})
        if p and #p:trim() > 0 then
            return p:trim()
        end
    end

    -- 2. Priority candidate search for modern Lua versions
    local candidates = {"lua5.5", "lua5.4", "lua55", "lua54", "lua"}
    for _, name in ipairs(candidates) do
        local p = try { function() return os.iorunv("which", {name}) end }
        if p and #p:trim() > 0 then
            p = p:trim()
            local ver_str = try { function() return os.iorunv(p, {"-v"}) end } or ""
            local major, minor = ver_str:match("Lua (%d+)%.(%d+)")
            if major and minor then
                local v = tonumber(major) * 10 + tonumber(minor)
                if v >= 54 then
                    return p
                end
            end
        end
    end

    -- 3. Fallback: check plain 'lua' command
    local fallback = try { function() return os.iorunv("which", {"lua"}) end }
    if fallback and #fallback:trim() > 0 then
        return fallback:trim()
    end

    return "lua"
end

-- Get canonical LUA_PATH string for a project
function get_lua_paths(projdir)
    projdir = projdir or os.projectdir()
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
    table.insert(paths, path.join(projdir, "build/lua/share/lua/5.4/?.lua"))
    table.insert(paths, path.join(projdir, "build/lua/share/lua/5.4/?/init.lua"))

    -- 3. Vendored and local dependencies (vendor / lua_modules)
    table.insert(paths, path.join(projdir, "vendor/?.lua"))
    table.insert(paths, path.join(projdir, "vendor/?/init.lua"))
    table.insert(paths, path.join(projdir, "vendor/share/lua/5.4/?.lua"))
    table.insert(paths, path.join(projdir, "vendor/share/lua/5.4/?/init.lua"))
    table.insert(paths, path.join(projdir, "lua_modules/share/lua/5.4/?.lua"))
    table.insert(paths, path.join(projdir, "lua_modules/share/lua/5.4/?/init.lua"))

    -- 4. Join and append Lua system default fallback (;;)
    local path_str = table.concat(paths, ";") .. ";;"
    local user_lua_path = os.getenv("LUA_PATH")
    if user_lua_path and #user_lua_path > 0 then
        path_str = path_str .. ";" .. user_lua_path
    end

    return path_str
end

-- Get canonical LUA_CPATH string for dynamic C extensions (.so / .dll)
function get_lua_cpaths(projdir)
    projdir = projdir or os.projectdir()
    local cpaths = {}
    local ext = (os.host() == "windows") and "dll" or "so"

    -- 1. Project local build / staging directory
    table.insert(cpaths, path.join(projdir, "build/lua/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/?/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/?/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/lua/5.4/?." .. ext))
    table.insert(cpaths, path.join(projdir, "build/lua/lib/lua/5.4/?/?." .. ext))

    -- 2. Vendored C modules
    table.insert(cpaths, path.join(projdir, "vendor/lib/lua/5.4/?." .. ext))
    table.insert(cpaths, path.join(projdir, "vendor/lib/lua/5.4/?/?." .. ext))
    table.insert(cpaths, path.join(projdir, "lua_modules/lib/lua/5.4/?." .. ext))
    table.insert(cpaths, path.join(projdir, "lua_modules/lib/lua/5.4/?/?." .. ext))

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
            local relpath = nil
            local rootdir = target:extraconf("files", srcfile, "rootdir") or target:values("forge.lua.rootdir")
            if rootdir then
                relpath = path.relative(srcfile, rootdir)
            else
                local norm = path.normalize(srcfile)
                if norm:startswith("src/") then
                    relpath = norm:sub(5)
                elseif norm:startswith("lua/") then
                    relpath = norm:sub(5)
                elseif norm:startswith("lib/") then
                    relpath = norm:sub(5)
                else
                    relpath = norm
                end
            end

            local dstfile = path.join(staging_dir, relpath)
            if not os.isfile(dstfile) or os.mtime(srcfile) > os.mtime(dstfile) then
                os.mkdir(path.directory(dstfile))
                os.cp(srcfile, dstfile)
                cprint("${dim}[forge] Staged %s -> %s${clear}", path.relative(srcfile, projdir), relpath)
            end
        end
    end
end
