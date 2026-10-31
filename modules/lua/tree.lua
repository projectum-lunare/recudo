-- Installed Lua tree: manifest, runtime note, require() patterns and bundle inputs.
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local modules_root = path.directory(os.scriptdir())
import("lua.names", {rootdir = modules_root, inherit = true})

local MANIFEST_REL = "share/forge/lua-modules.lua"

function manifest_file(installdir)
    return path.join(installdir, MANIFEST_REL)
end

function has_manifest(installdir)
    return installdir and os.isfile(manifest_file(installdir))
end

function load_manifest(installdir)
    if not has_manifest(installdir) then
        return nil
    end
    local data = io.load(manifest_file(installdir))
    if type(data) == "table" then
        return data
    end
    return nil
end

local SEARCH_NOTE = "share/forge/lua-search.lua"

-- Relative LUA_PATH / LUA_CPATH for a tree installed by forge.lua.module.
function module_search_envs(ext)
    ext = ext or ".so"
    if not ext:startswith(".") then
        ext = "." .. ext
    end
    return {
        LUA_PATH = {
            "share/lua/?.lua",
            "share/lua/?/init.lua",
            "share/lua/5.4/?.lua",
            "share/lua/5.4/?/init.lua",
            "share/lua/5.5/?.lua",
            "share/lua/5.5/?/init.lua"
        },
        LUA_CPATH = {
            "lib/?" .. ext,
            "lib/lua/5.4/?" .. ext,
            "lib/lua/5.5/?" .. ext
        }
    }
end

function write_module_search(installdir, ext)
    local dir = path.join(installdir, "share/forge")
    os.mkdir(dir)
    io.save(path.join(installdir, SEARCH_NOTE), {envs = module_search_envs(ext)})
end

-- Publish the paths written by forge.lua.module onto the xmake package.
function apply_search_envs(package)
    local ext = ".so"
    if package.is_plat and package:is_plat("windows", "mingw") then
        ext = ".dll"
    end
    local note = path.join(package:installdir(), SEARCH_NOTE)
    local data = os.isfile(note) and io.load(note) or nil
    local envs = type(data) == "table" and data.envs or nil
    if type(envs) ~= "table" then
        envs = module_search_envs(ext)
    end
    for name, values in pairs(envs) do
        for _, value in ipairs(table.wrap(values)) do
            package:addenv(name, value)
        end
        package:mark_as_pathenv(name)
    end
end

local RUNTIME_REL = "share/forge/lua-runtime.lua"

function load_runtime(installdir)
    if not installdir then
        return nil
    end
    local file = path.join(installdir, RUNTIME_REL)
    if not os.isfile(file) then
        return nil
    end
    local data = io.load(file)
    if type(data) ~= "table" or type(data.installdir) ~= "string" or not os.isdir(data.installdir) then
        return nil
    end
    return data
end

local function add_root(roots, seen, dir)
    if not dir or dir == "" or seen[dir] or not has_manifest(dir) then
        return
    end
    seen[dir] = true
    table.insert(roots, dir)
end

-- A fetch result may record the library path without the install directory.
local function consider_root(roots, seen, value)
    if type(value) ~= "string" or not path.is_absolute(value) then
        return
    end
    add_root(roots, seen, value)
    local parent = path.directory(value)
    add_root(roots, seen, parent)
    add_root(roots, seen, path.directory(parent))
end

function roots_of(target)
    local roots = {}
    local seen = {}
    if not target or not target.orderpkgs then
        return roots
    end
    for _, pkg in ipairs(target:orderpkgs()) do
        if pkg.installdir then
            add_root(roots, seen, pkg:installdir({readonly = true}))
        end
        if pkg.get then
            for _, key in ipairs({"libfiles", "linkdirs", "includedirs"}) do
                local value = pkg:get(key)
                if type(value) == "table" then
                    for _, item in ipairs(value) do
                        consider_root(roots, seen, item)
                    end
                else
                    consider_root(roots, seen, value)
                end
            end
            local envs = pkg:get("envs")
            if type(envs) == "table" then
                for _, key in ipairs({"LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "PATH"}) do
                    local values = envs[key]
                    if type(values) == "table" then
                        for _, item in ipairs(values) do
                            consider_root(roots, seen, item)
                        end
                    else
                        consider_root(roots, seen, values)
                    end
                end
            end
        end
    end
    return roots
end

function has_shared_native(roots)
    for _, root in ipairs(roots or {}) do
        local manifest = load_manifest(root)
        if manifest then
            for _, mod in ipairs(manifest.modules or {}) do
                if mod.kind == "c" and mod.ext then
                    return true
                end
            end
        end
    end
    return false
end

function search_patterns(roots, kind)
    local patterns = {}
    for _, root in ipairs(roots or {}) do
        local manifest = load_manifest(root)
        if manifest then
            local ver = manifest.luaver or "5.4"
            local has_lua = false
            local exts = {}
            for _, mod in ipairs(manifest.modules or {}) do
                if mod.kind == "lua" then
                    has_lua = true
                elseif mod.kind == "c" and mod.ext then
                    exts[mod.ext] = true
                end
            end
            if kind == "path" and has_lua then
                table.insert(patterns, path.join(root, "share/lua", ver, "?.lua"))
                table.insert(patterns, path.join(root, "share/lua", ver, "?/init.lua"))
            elseif kind == "cpath" then
                for ext, _ in pairs(exts) do
                    table.insert(patterns, path.join(root, "lib/lua", ver, "?." .. ext))
                end
            end
        end
    end
    return patterns
end

-- Lua sources to embed and static C modules to link into a bundle.
function bundle_sources(roots)
    local files = {}
    local file_map = {}
    local module_map = {}
    local natives = {}
    local cpaths = {}
    for _, root in ipairs(roots or {}) do
        local manifest = load_manifest(root)
        if manifest then
            local ver = manifest.luaver or "5.4"
            local exts = {}
            for _, mod in ipairs(manifest.modules or {}) do
                if mod.kind == "lua" then
                    local abs = path.join(root, mod.relpath)
                    if not os.isfile(abs) then
                        raise("bundled Lua module '" .. mod.name .. "' is missing: " .. abs)
                    end
                    table.insert(files, abs)
                    file_map[abs] = module_lua_relpath(mod.name)
                    module_map[abs] = mod.name
                elseif mod.kind == "c" and mod.ext then
                    exts[mod.ext] = true
                elseif mod.kind == "c" and mod.link and mod.symbol then
                    table.insert(natives, {
                        name = mod.name,
                        symbol = mod.symbol,
                        link = mod.link,
                        linkdir = path.join(root, "lib")
                    })
                end
            end
            for ext, _ in pairs(exts) do
                table.insert(cpaths, path.join(root, "lib/lua", ver, "?." .. ext))
            end
        end
    end
    return {
        files = files,
        file_map = file_map,
        module_map = module_map,
        natives = natives,
        cpath = table.concat(cpaths, ";")
    }
end


function library_is_shared(root)
    if not root then
        return false
    end
    local lib = path.join(root, "lib")
    local bin = path.join(root, "bin")
    local function has_file(dir, name)
        return os.isdir(dir) and os.isfile(path.join(dir, name))
    end
    if has_file(lib, "liblua.so") or has_file(lib, "liblua.dylib") or has_file(lib, "lua.dll") then
        return true
    end
    if has_file(bin, "lua.dll") or has_file(bin, "lua54.dll") or has_file(bin, "lua55.dll") then
        return true
    end
    if os.isdir(lib) then
        local sos = os.files(path.join(lib, "liblua.so*"))
        if sos and #sos > 0 then
            return true
        end
    end
    return false
end

function replace_manifest(installdir, ver, records)
    local mdir = path.join(installdir, "share/forge")
    os.mkdir(mdir)
    local manifest = manifest_file(installdir)
    io.save(manifest, {luaver = ver, modules = records})
    if not os.isfile(manifest) then
        raise("failed to write lua module manifest: " .. manifest)
    end
end

-- One target's after_install merges into a manifest other targets may already have written.
function upsert_record(installdir, record, ver)
    local mdir = path.join(installdir, "share/forge")
    os.mkdir(mdir)
    local file = manifest_file(installdir)
    local data = os.isfile(file) and io.load(file) or {luaver = ver, modules = {}}
    if type(data) ~= "table" then
        data = {luaver = ver, modules = {}}
    end
    data.luaver = data.luaver or ver
    data.modules = data.modules or {}
    local replaced = false
    for i, mod in ipairs(data.modules) do
        if mod.name == record.name then
            data.modules[i] = record
            replaced = true
        end
    end
    if not replaced then
        table.insert(data.modules, record)
    end
    io.save(file, data)
end

function save_runtime(installdir, lua_installdir, shared)
    local mdir = path.join(installdir, "share/forge")
    os.mkdir(mdir)
    local runtime_file = path.join(mdir, "lua-runtime.lua")
    io.save(runtime_file, {installdir = lua_installdir, shared = shared})
    if not os.isfile(runtime_file) then
        raise("failed to write lua runtime descriptor: " .. runtime_file)
    end
end
