-- Build and install a Lua module recipe.
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- import("lua.module") re-exports this together with the name and tree helpers.

local modules_root = path.directory(os.scriptdir())
import("lua.names", {rootdir = modules_root, inherit = true})
import("lua.tree", {rootdir = modules_root, inherit = true})

-- Captured when this module is loaded. os.scriptdir() later follows the caller.
local FORGE_ROOT = path.directory(path.directory(os.scriptdir()))
local catalog = import("catalog", {rootdir = path.directory(os.scriptdir()), anonymous = true})

function supports_dynamic(plat)
    return not catalog.is_static(plat)
end

function forge_root()
    return FORGE_ROOT
end

-- Install an xmake project that uses forge.lua.module. A project that already
-- includes Forge is left alone. One that only declares targets receives Forge
-- and the lua dependency around it.
function install_project(package, configs)
    local xmake_tools = import("package.tools.xmake")
    local project = os.isfile("xmake.lua") and io.readfile("xmake.lua") or ""

    configs = configs or {}
    if configs.kind == nil and package.config and package:config("shared") ~= nil then
        configs.kind = package:config("shared") and "shared" or "static"
    end

    -- Strip standalone repository/addon declarations during package build to
    -- prevent recursive xmake locks and redundant network clones:
    if project:find("add_addons", 1, true) or project:find("add_repositories", 1, true) then
        local cleaned = project:gsub("add_addons%b()", ""):gsub("add_repositories%b()", "")
        if cleaned ~= project then
            io.writefile("xmake.lua", cleaned)
            project = cleaned
        end
    end

    local envs = xmake_tools.buildenvs(package)
    if not project:find("/forge.lua", 1, true) and not project:find("\\forge.lua", 1, true) then
        local rc = os.tmpfile() .. ".lua"
        local forge_lua = path.join(FORGE_ROOT, "includes", "forge.lua")
        io.writefile(rc, table.concat({
            'add_rules("mode.release", "mode.debug")',
            'add_requires("lua")',
            "includes(" .. string.format("%q", forge_lua) .. ")",
            ""
        }, "\n"))
        envs.XMAKE_RCFILES = envs.XMAKE_RCFILES or {}
        table.insert(envs.XMAKE_RCFILES, rc)
    end
    xmake_tools.install(package, configs, {envs = envs})
    apply_search_envs(package)
end

-- Lua splits LUA_PATH on ';', including on Linux, where xmake joins path envs with ':'.
function lua_test(package, expr)
    if package:is_cross() then
        return
    end

    local ext = package:is_plat("windows", "mingw") and ".dll" or ".so"
    local search = module_search_envs(ext)
    local lua_paths = {}
    local lua_cpaths = {}

    local function add_package_paths(pkg)
        local dir = pkg.installdir and pkg:installdir()
        if dir and os.isdir(dir) then
            local note = path.join(dir, "share/forge/lua-search.lua")
            local data = os.isfile(note) and io.load(note) or nil
            local envs = type(data) == "table" and data.envs or search
            for _, p in ipairs(table.wrap(envs.LUA_PATH)) do
                local full = path.normalize(path.join(dir, p))
                if not table.contains(lua_paths, full) then
                    table.insert(lua_paths, full)
                end
            end
            for _, p in ipairs(table.wrap(envs.LUA_CPATH)) do
                local full = path.normalize(path.join(dir, p))
                if not table.contains(lua_cpaths, full) then
                    table.insert(lua_cpaths, full)
                end
            end
        end
    end

    add_package_paths(package)
    if package.orderdeps then
        for _, dep in ipairs(table.wrap(package:orderdeps())) do
            add_package_paths(dep)
        end
    end

    local function lua_list(name, extra)
        local cur = os.getenv(name)
        local list = {}
        for _, p in ipairs(extra) do
            table.insert(list, p)
        end
        if cur then
            if not package:is_plat("windows", "mingw") then
                cur = cur:gsub(":", ";")
            end
            for p in cur:gmatch("[^;]+") do
                if path.is_absolute(p) and not table.contains(list, p) then
                    table.insert(list, p)
                end
            end
        end
        local result = table.concat(list, ";")
        if not result:endswith(";;") then
            result = result .. ";;"
        end
        return result
    end

    os.vrunv("lua", {"-e", expr}, {envs = {
        LUA_PATH = lua_list("LUA_PATH", lua_paths),
        LUA_CPATH = lua_list("LUA_CPATH", lua_cpaths)
    }})
end

-- Build the recipe directory as an xmake project. The recipe file is that project.
-- The rc file includes Forge instead of pasting it: a pasted script would see
-- the recipe directory as scriptdir and miss the addon rules.
function build(package)
    local work = path.absolute(package:sourcedir())
    local xmake_tools = import("package.tools.xmake")
    local envs = xmake_tools.buildenvs(package)
    local rcdir = package:cachedir()
    os.mkdir(rcdir)
    local forge_lua = path.join(FORGE_ROOT, "includes", "forge.lua")
    local rcfile = path.join(rcdir, "forge-project.lua")
    io.writefile(rcfile, "includes(" .. string.format("%q", forge_lua) .. ")\n")
    envs.XMAKE_RCFILES = envs.XMAKE_RCFILES or {}
    table.insert(envs.XMAKE_RCFILES, rcfile)
    envs.FORGE_LUA_PROJECT = "1"
    envs.FORGE_LUA_ROOT = FORGE_ROOT
    envs.XMAKE_CONFIGDIR = work
    local kind = package:config("shared") and "shared" or "static"
    local xmake = os.programfile()
    os.execv(xmake, {"f", "-P", work, "-y", "-c",
        "--plat=" .. package:plat(), "--arch=" .. package:arch(),
        "--mode=" .. (package:is_debug() and "debug" or "release"),
        "--kind=" .. kind}, {curdir = work, envs = envs})
    os.execv(xmake, {"build", "-P", work}, {curdir = work, envs = envs})
    os.execv(xmake, {"install", "-P", work, "-y", "--packages=n", "-o", package:installdir()}, {curdir = work, envs = envs})
    apply_search_envs(package)
end

-- Static mode builds only an archive. Dynamic mode builds only a shared module.
-- A platform that cannot dlopen stays static even when shared=true.
function prefers_static(package)
    local plat = package.plat and package:plat() or nil
    if not supports_dynamic(plat) then
        return true
    end
    local shared = package.config and package:config("shared")
    return shared ~= true
end

function shared_extension(package)
    local plat = package.plat and package:plat() or os.host()
    if plat == "windows" or plat == "mingw" then
        return "dll"
    end
    return "so"
end

local function slash(p)
    return (tostring(p):gsub("\\", "/"))
end

local function source_extension(path)
    local lower = tostring(path):lower()
    if lower:endswith(".lua") then
        return "lua"
    elseif lower:endswith(".cpp") or lower:endswith(".cc") or lower:endswith(".cxx") then
        return "cpp"
    elseif lower:endswith(".c") or lower:endswith(".h") then
        return "c"
    end
    return nil
end

-- A filename ends in a source extension or exists on disk. Anything else is the
-- source text itself, written out before it is compiled or installed.
local function is_path_string(src)
    if type(src) ~= "string" then
        return false
    end
    local trimmed = src:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed:find("\n", 1, true) or trimmed:find("\r", 1, true) then
        return false
    end
    if source_extension(trimmed) then
        return true
    end
    return os.isfile(trimmed)
end

local function inline_extension(content)
    if content:find("#include", 1, true) or content:find("lua_State", 1, true) or content:find("luaopen_", 1, true) then
        return "c"
    end
    return "lua"
end

local function classify_source(name, src, index)
    if type(src) == "table" and type(src.inline) == "string" then
        local ext = src.lang or src.ext or inline_extension(src.inline)
        if ext == "c++" or ext == "cxx" or ext == "cc" then
            ext = "cpp"
        elseif ext ~= "lua" and ext ~= "cpp" then
            ext = "c"
        end
        local file = src.file or (link_name(name) .. (index > 1 and ("_" .. index) or "") .. "." .. ext)
        return {inline = src.inline, file = file, ext = ext}
    end
    if type(src) == "string" and not is_path_string(src) then
        local ext = inline_extension(src)
        local file = link_name(name) .. (index > 1 and ("_" .. index) or "") .. "." .. ext
        return {inline = src, file = file, ext = ext}
    end
    local path_src = type(src) == "string" and src or src.path or src[1]
    return {path = path_src, ext = source_extension(path_src) or "c"}
end

local function normalize_module(name, spec)
    local sources, defines, includedirs, links
    if type(spec) == "string" then
        sources = {spec}
        defines, includedirs, links = {}, {}, {}
    elseif type(spec) == "table" and spec.sources then
        sources = table.wrap(spec.sources)
        defines = table.wrap(spec.defines)
        includedirs = table.wrap(spec.includedirs)
        links = table.wrap(spec.links)
    elseif type(spec) == "table" then
        sources = {}
        for _, item in ipairs(spec) do
            table.insert(sources, item)
        end
        defines, includedirs, links = {}, {}, {}
    else
        raise("lua module '" .. tostring(name) .. "' has an invalid source description")
    end

    if #sources == 0 then
        raise("lua module '" .. tostring(name) .. "' has no sources")
    end

    local inputs = {}
    local all_lua = true
    for index, src in ipairs(sources) do
        local input = classify_source(name, src, index)
        table.insert(inputs, input)
        if input.ext ~= "lua" then
            all_lua = false
        end
    end
    if all_lua and #inputs ~= 1 then
        raise("lua module '" .. tostring(name) .. "' accepts one .lua file")
    end

    return {
        name = name,
        kind = all_lua and "lua" or "c",
        inputs = inputs,
        sources = {},
        defines = defines,
        includedirs = includedirs,
        links = links
    }
end

local function materialize_spec(spec, dir, curdir)
    local files = {}
    for _, input in ipairs(spec.inputs or {}) do
        local rel
        if input.inline then
            rel = input.file
            local dst = path.join(dir, rel)
            os.mkdir(path.directory(dst))
            io.writefile(dst, input.inline)
        else
            local abs = input.path
            if not path.is_absolute(abs) then
                abs = path.absolute(abs, curdir)
            end
            rel = input.path
            if path.is_absolute(rel) then
                rel = path.filename(rel)
            end
            local dst = path.join(dir, rel)
            os.mkdir(path.directory(dst))
            os.cp(abs, dst)
        end
        table.insert(files, slash(rel))
    end
    spec.sources = files
    spec._staged = dir
end

local function sorted_modules(modules)
    local names = {}
    for name, _ in pairs(modules or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    local specs = {}
    for _, name in ipairs(names) do
        table.insert(specs, normalize_module(name, modules[name]))
    end
    return specs
end

function luaver_of(package)
    if package and package.dep then
        local lua = package:dep("lua") or package:dep("luajit")
        if lua and lua.version then
            local parsed = lua_version_string(lua:version())
            if parsed then
                return parsed
            end
        end
    end
    return "5.4"
end

local function abs_in(curdir, src)
    if path.is_absolute(src) then
        return src
    end
    return path.absolute(src, curdir)
end

local function lua_includes(package)
    local dep = package:dep("lua") or package:dep("luajit")
    if not dep then
        raise("a C Lua module requires add_deps(\"lua\")")
    end
    local info = dep:fetch() or {}
    local incs = table.join(table.wrap(info.includedirs), table.wrap(info.sysincludedirs))
    if #incs == 0 then
        raise("lua headers not found from package(" .. dep:name() .. ")")
    end
    return info, incs
end

local function child_envs(package)
    local xmake_tools = import("package.tools.xmake")
    local envs = xmake_tools.buildenvs(package)
    local rc = os.tmpfile() .. ".lua"
    local forge_lua = path.join(FORGE_ROOT, "includes", "forge.lua")
    io.writefile(rc, "includes(" .. string.format("%q", forge_lua) .. ")\n")
    envs.XMAKE_RCFILES = envs.XMAKE_RCFILES or {}
    table.insert(envs.XMAKE_RCFILES, rc)
    return envs
end

local function emit_target(lines, spec, opt)
    local link = link_name(spec.name)
    local leaf = module_parts(spec.name)
    leaf = leaf[#leaf]
    table.insert(lines, string.format("target(%q)", opt.target_name))
    table.insert(lines, string.format("    set_kind(%q)", opt.kind))
    if opt.kind == "shared" then
        table.insert(lines, "    set_prefixname(\"\")")
        table.insert(lines, string.format("    set_basename(%q)", leaf))
        table.insert(lines, string.format("    set_extension(%q)", "." .. opt.ext))
    else
        table.insert(lines, string.format("    set_basename(%q)", link))
    end
    if opt.rule then
        table.insert(lines, string.format("    add_rules(%q, {override = true})", opt.rule))
    end
    for _, src in ipairs(spec.sources) do
        table.insert(lines, string.format("    add_files(%q)", src))
    end
    for _, inc in ipairs(opt.includedirs) do
        table.insert(lines, string.format("    add_includedirs(%q)", inc))
    end
    table.insert(lines, "    add_defines(\"LUA_COMPAT_5_3\")")
    for _, def in ipairs(spec.defines) do
        table.insert(lines, string.format("    add_defines(%q)", def))
    end
    for _, linkname in ipairs(opt.syslinks) do
        table.insert(lines, string.format("    add_syslinks(%q)", linkname))
    end
    for _, linkname in ipairs(spec.links) do
        table.insert(lines, string.format("    add_syslinks(%q)", linkname))
    end
    if opt.kind == "shared" and not opt.vintage then
        table.insert(lines, "    add_cxflags(\"-fPIC\", {tools = {\"gcc\", \"clang\", \"gxx\", \"clangxx\"}})")
    end
    if opt.kind == "shared" and opt.plat == "macosx" then
        table.insert(lines, "    add_shflags(\"-undefined\", \"dynamic_lookup\")")
    end
    if opt.kind == "shared" and (opt.plat == "windows" or opt.plat == "mingw") then
        for _, dir in ipairs(opt.lua_linkdirs or {}) do
            table.insert(lines, string.format("    add_linkdirs(%q)", dir))
        end
        for _, lib in ipairs(opt.lua_links or {}) do
            table.insert(lines, string.format("    add_links(%q)", lib))
        end
    end
    table.insert(lines, "")
end

local function vintage_rule(plat)
    if plat == "dos" or plat == "os2" then
        return "forge.watcom"
    elseif plat == "wince" then
        return "forge.evc3"
    end
    return nil
end

local function find_artifact(installdir, basenames, exts)
    for _, sub in ipairs({"lib", "bin"}) do
        for _, base in ipairs(basenames) do
            for _, ext in ipairs(exts) do
                local candidates = {
                    path.join(installdir, sub, base .. ext),
                    path.join(installdir, sub, "lib" .. base .. ext)
                }
                for _, candidate in ipairs(candidates) do
                    if os.isfile(candidate) then
                        return candidate
                    end
                end
            end
        end
    end
    return nil
end

local function compile_cmodules(package, specs, opt)
    local curdir = (opt and opt.srcdir) or os.curdir()
    local work = path.join(package:builddir(), "forge-lua")
    os.tryrm(work)
    os.mkdir(work)

    local copied = {}
    for _, spec in ipairs(specs) do
        for _, src in ipairs(spec.sources) do
            if not copied[src] then
                local abs = abs_in(curdir, src)
                local dst = path.join(work, src)
                os.mkdir(path.directory(dst))
                os.cp(abs, dst)
                copied[src] = true
            end
        end
        for _, inc in ipairs(spec.includedirs) do
            spec._abs_includedirs = spec._abs_includedirs or {}
            table.insert(spec._abs_includedirs, abs_in(curdir, inc))
        end
    end

    local info, incs = lua_includes(package)
    local plat = package:plat()
    local rule = vintage_rule(plat)
    local static_only = prefers_static(package)
    local ext = shared_extension(package)
    local syslinks = table.wrap(package:get("syslinks"))

    local lines = {
        "-- Generated by Projectum Lunare Forge",
        "add_rules(\"mode.debug\", \"mode.release\")",
        ""
    }
    for _, spec in ipairs(specs) do
        local includedirs = table.join(incs, spec._abs_includedirs or {})
        local spec_opt = {
            ext = ext,
            rule = rule,
            includedirs = includedirs,
            syslinks = syslinks,
            plat = plat,
            vintage = rule ~= nil,
            lua_linkdirs = table.wrap(info.linkdirs),
            lua_links = table.wrap(info.links)
        }
        if static_only then
            spec_opt.target_name = link_name(spec.name)
            spec_opt.kind = "static"
        else
            spec_opt.target_name = link_name(spec.name) .. "_shared"
            spec_opt.kind = "shared"
        end
        emit_target(lines, spec, spec_opt)
    end

    io.writefile(path.join(work, "xmake.lua"), table.concat(lines, "\n"))
    -- package.tools.xmake passes -P os.curdir() when a parent xmake.lua exists.
    -- The install script's directory is that parent, so the generated project has to
    -- be the current directory or the child xmake configures the outer project.
    local envs = child_envs(package)
    local oldir = os.cd(work)
    local install_err
    local install_ok = try {
        function ()
            import("package.tools.xmake").install(package, {}, {curdir = work, envs = envs})
            return true
        end,
        catch {
            function (err)
                install_err = err
            end
        }
    }
    if oldir then
        os.cd(oldir)
    end
    if not install_ok then
        raise(install_err or "failed to compile Lua C module")
    end
    return ext, not static_only
end

-- Install modules described by an xmake table.
--
-- modules = {
--     ["forge.hello"] = "hello.lua",
--     ["forge.native"] = "native.c",
--     ["socket.core"] = {
--         sources = {"src/core.c"},
--         defines = {"SOCKET_EXPORTS"},
--         links = {"ws2_32"}
--     }
-- }
function install(package, opt)
    opt = opt or {}
    local specs = sorted_modules(opt.modules)
    if #specs == 0 then
        raise("lua.module.install: modules is empty")
    end

    local ver = opt.luaver or luaver_of(package)
    local installdir = package:installdir()
    local stage_base = package.builddir and package:builddir() or path.join(installdir, ".forge-src")
    local stage = path.join(stage_base, "forge-lua-src")
    os.tryrm(stage)
    os.mkdir(stage)
    for _, spec in ipairs(specs) do
        materialize_spec(spec, stage, os.curdir())
    end
    local cmodules = {}
    for _, spec in ipairs(specs) do
        if spec.kind == "c" then
            table.insert(cmodules, spec)
        end
    end

    local shared_ext, built_shared
    if #cmodules > 0 then
        if not prefers_static(package) and not lua_dep_is_shared(package) then
            raise("lua.module.install: dynamic mode needs a shared liblua. " ..
                  "Configure the project with --kind=shared. Platforms without dynamic linking stay static.")
        end
        shared_ext, built_shared = compile_cmodules(package, cmodules, {luaver = ver, srcdir = stage})
    end

    local records = {}
    local added_linkdir = false
    for _, spec in ipairs(specs) do
        if spec.kind == "lua" then
            local rel = slash(path.join("share/lua", ver, module_lua_relpath(spec.name, spec.sources[1])))
            local dst = path.join(installdir, rel)
            os.mkdir(path.directory(dst))
            os.cp(path.join(spec._staged, spec.sources[1]), dst)
            table.insert(records, {
                name = spec.name,
                kind = "lua",
                relpath = rel
            })
        else
            local link = link_name(spec.name)
            local record = {
                name = spec.name,
                kind = "c",
                symbol = open_symbol(spec.name),
                link = link
            }
            if built_shared then
                local leaf = module_parts(spec.name)
                leaf = leaf[#leaf]
                local shared_file = find_artifact(installdir, {leaf, link}, {"." .. shared_ext})
                if not shared_file then
                    raise("shared library for Lua module '" .. spec.name .. "' was not installed into " .. installdir)
                end
                local shared_rel = slash(path.join("lib/lua", ver, module_c_relpath(spec.name, shared_ext)))
                local shared_dst = path.join(installdir, shared_rel)
                os.mkdir(path.directory(shared_dst))
                os.cp(shared_file, shared_dst)
                if path.normalize(shared_file) ~= path.normalize(shared_dst) then
                    os.rm(shared_file)
                end
                record.ext = shared_ext
                record.shared_relpath = shared_rel
                record.relpath = shared_rel
            else
                local static_file = find_artifact(installdir, {link}, {".a", ".lib"})
                if not static_file then
                    raise("static archive for Lua module '" .. spec.name .. "' was not installed into " .. installdir)
                end
                record.relpath = slash(path.relative(static_file, installdir))
                package:add("links", link)
                if not added_linkdir then
                    package:add("linkdirs", "lib")
                    added_linkdir = true
                end
            end
            table.insert(records, record)
        end
    end

    replace_manifest(installdir, ver, records)

    -- Record the interpreter directory xmake actually used. The runner reads this
    -- instead of rebuilding the package cache path from a version and a hash.
    local lua_dep = package.dep and (package:dep("lua") or package:dep("luajit"))
    if lua_dep and lua_dep.installdir then
        save_runtime(installdir, lua_dep:installdir({readonly = true}), lua_dep_is_shared(package))
    end
end

function lua_dep_is_shared(package)
    local dep = package and package.dep and (package:dep("lua") or package:dep("luajit"))
    if not dep or not dep.installdir then
        return false
    end
    if dep.config and dep:config("shared") == true then
        return true
    end
    return library_is_shared(dep:installdir({readonly = true}))
end

-- Fetch hook for a pure Lua package, which installs no C library.
function fetch(package, opt)
    opt = opt or {}
    if opt.system then
        return
    end
    if has_manifest(package:installdir({readonly = true})) then
        return {}
    end
end
