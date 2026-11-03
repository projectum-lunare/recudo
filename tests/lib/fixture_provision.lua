-- Projectum Lunare Recudo - test fixture provisioning
--
-- Every real toolchain is a package recipe under repository/tools/packages/
-- and is installed through `xmake require`. Nothing in the product path uses
-- this file.
--
-- This is a small local-install engine used *only* by tests/test_provision.lua
-- to exercise an install pipeline end to end against synthetic specs and local
-- fixture archives (checksum verification, dependency ordering, host filters,
-- idempotence, smoke tests). Keeping it under tests/ makes that scope explicit:
-- it is test scaffolding, not a second provisioning channel.

import("utils.archive")
import("net.http")

local _runtime = {}

-- -----------------------------------------------------------------------------
-- Fixture registry
-- -----------------------------------------------------------------------------

function register_tool(spec)
    _runtime[spec.id:lower()] = spec
    for _, alias in ipairs(spec.aliases or {}) do
        _runtime[alias:lower()] = spec
    end
end

function all_specs()
    local out = {}
    for _, spec in pairs(_runtime) do
        table.insert(out, spec)
    end
    return out
end

function resolve(id)
    if type(id) == "table" then
        return id
    end
    id = tostring(id):lower()
    if _runtime[id] then
        return _runtime[id]
    end
    for _, spec in pairs(_runtime) do
        if spec.id:lower() == id then
            return spec
        end
        for _, alias in ipairs(spec.aliases or {}) do
            if alias:lower() == id then
                return spec
            end
        end
    end
    return nil
end

-- -----------------------------------------------------------------------------
-- Context
-- -----------------------------------------------------------------------------

local function install_dir_for(spec, opts)
    if opts.dir then
        return opts.dir
    end
    for _, name in ipairs(table.wrap(spec.env_names)) do
        local value = os.getenv(name)
        if value and #value > 0 then
            return value
        end
    end
    if os.host() == "windows" then
        local appdata = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA")
        if appdata then
            return path.join(appdata, spec.id)
        end
    end
    local home = os.getenv("HOME") or os.getenv("USERPROFILE")
    if home then
        return path.join(home, ".local/opt", spec.id)
    end
    return nil
end

function context(spec, opts)
    opts = opts or {}
    local installdir = opts.dir
    if not installdir and type(spec.default_dir) == "function" then
        installdir = spec.default_dir()
    end
    installdir = installdir or install_dir_for(spec, opts)

    local cache = opts.cache_dir
    if not cache and type(spec.default_cache) == "function" then
        cache = spec.default_cache()
    end
    cache = cache or path.join(os.getenv("XDG_CACHE_HOME")
        or path.join(os.getenv("HOME") or "", ".cache"), "recudo", spec.id)

    return {
        spec = spec,
        opts = opts,
        install_dir = installdir and path.normalize(installdir) or nil,
        cache_dir = path.normalize(cache),
        tmp_dir = path.join(cache, "tmp"),
        edition = spec.editions and opts.edition and spec.editions[opts.edition],
        edition_key = opts.edition,
    }
end

local function expand_str(value, ctx)
    value = value:gsub("{install_dir}", ctx.install_dir or "")
    return (value:gsub("{cache_dir}", ctx.cache_dir or ""))
end

function expand(value, ctx)
    if type(value) == "table" then
        local out = {}
        for k, v in pairs(value) do
            out[k] = expand(v, ctx)
        end
        return out
    end
    if type(value) == "string" then
        return expand_str(value, ctx)
    end
    return value
end

function tool_envs(ctx)
    local envs = {}
    local env_map = expand(ctx.spec.env_map or {}, ctx)
    for key, value in pairs(env_map) do
        envs[key] = type(value) == "table" and table.concat(value, path.envsep()) or tostring(value)
    end
    local tool_paths = {}
    if type(env_map.PATH) == "table" then
        for _, p in ipairs(env_map.PATH) do
            table.insert(tool_paths, p)
        end
    elseif type(env_map.PATH) == "string" then
        table.insert(tool_paths, env_map.PATH)
    end
    if #tool_paths > 0 then
        envs.PATH = table.concat(tool_paths, path.envsep()) .. path.envsep() .. (os.getenv("PATH") or "")
    end
    return envs
end

-- -----------------------------------------------------------------------------
-- Probe
-- -----------------------------------------------------------------------------

function probe(ctx)
    if not ctx.install_dir or not os.isdir(ctx.install_dir) then
        return false
    end
    local checks = {}
    if ctx.spec.check_file then
        table.insert(checks, ctx.spec.check_file)
    end
    for _, rel in ipairs(table.wrap(ctx.spec.check_files)) do
        table.insert(checks, rel)
    end
    for _, rel in ipairs(checks) do
        local f = path.join(ctx.install_dir, rel)
        if not (os.isfile(f) or os.isexec(f)) then
            return false
        end
    end
    return true
end

function is_installed(id_or_spec, opts)
    local spec = resolve(id_or_spec)
    if not spec then
        return false
    end
    return probe(context(spec, opts))
end

-- -----------------------------------------------------------------------------
-- Fixture install pipeline (local fixtures only: file:// or an existing path)
-- -----------------------------------------------------------------------------

local function sha256_of(file)
    for _, tool in ipairs({{"sha256sum"}, {"shasum", "-a", "256"}, {"openssl", "sha256"}}) do
        local hex = nil
        try {
            function ()
                hex = tostring(os.iorunv(tool[1], table.join(tool[2] or {}, {file})))
                    :match("^%s*([a-fA-F0-9]+)")
            end
        }
        if hex and #hex >= 64 then
            return hex:sub(1, 64):lower()
        end
    end
    return nil
end

function file_sha256(file)
    return sha256_of(file)
end

local function fetch(src, ctx)
    local dest = path.join(ctx.cache_dir, src.file or path.filename(src.url))
    os.mkdir(ctx.cache_dir)
    if src.url:startswith("file://") then
        os.cp(src.url:gsub("^file://", ""), dest)
    elseif os.isfile(src.url) then
        os.cp(src.url, dest)
    else
        import("net.http").download(src.url, dest)
    end
    if src.sha256 then
        local got = sha256_of(dest)
        if not got or got ~= src.sha256:lower() then
            raise("Checksum mismatch for '%s': expected %s, got %s", dest, src.sha256, tostring(got))
        end
    end
    return dest
end

function install(id_or_spec, opts)
    opts = opts or {}
    local spec = resolve(id_or_spec)
    if not spec then
        raise("Unknown fixture: '%s'", tostring(id_or_spec))
    end
    local ctx = context(spec, opts)

    if probe(ctx) and not opts.force then
        return true, "already installed at " .. ctx.install_dir
    end
    if spec.hosts and not table.contains(spec.hosts, os.host()) then
        return false, "not needed on this host (" .. os.host() .. "): " .. table.concat(spec.hosts, ", ")
    end
    for _, dep in ipairs(table.wrap(spec.dependencies)) do
        local ok, msg = install(dep, opts)
        if not ok and not (msg and (msg:find("already installed", 1, true)
            or msg:find("not needed", 1, true))) then
            return false, ("dependency '%s' failed: %s"):format(dep, msg or "unknown error")
        end
    end

    os.mkdir(ctx.cache_dir)
    os.mkdir(ctx.tmp_dir)
    os.mkdir(ctx.install_dir)

    for _, src in ipairs(table.wrap(spec.sources)) do
        local file = fetch(src, ctx)
        local dest = path.join(ctx.tmp_dir, src.key or "")
        os.mkdir(dest)
        -- archive.extract returns truthy even when it cannot handle the
        -- format, so verify that something actually landed before falling back
        try {
            function ()
                archive.extract(file, dest)
            end
        }
        local empty = #os.files(path.join(dest, "*")) == 0
                      and #os.dirs(path.join(dest, "*")) == 0
        if empty then
            os.runv("tar", {"-xf", file, "-C", dest})
        end

        local root = dest
        if (src.strip or 0) > 0 then
            local tops = os.dirs(path.join(dest, "*")) or {}
            if #tops == 1 then
                root = tops[1]
            end
        end
        local entries = table.join(os.dirs(path.join(root, "*")) or {},
                                   os.files(path.join(root, "*")) or {})
        for _, entry in ipairs(entries) do
            local target = path.join(ctx.install_dir, path.filename(entry))
            if os.isdir(entry) then
                os.cp(entry, target)
            else
                os.cp(entry, target)
            end
        end

        -- fixtures ship executable scripts: restore the bit on POSIX hosts
        if os.host() ~= "windows" then
            for pattern, _ in pairs(spec.permissions or {}) do
                for _, f in ipairs(os.files(path.join(ctx.install_dir, pattern)) or {}) do
                    try {
                        function ()
                            os.runv("chmod", {"0755", f})
                        end
                    }
                end
            end
        end
    end

    io.writefile(path.join(ctx.install_dir, ".recudo-provision"),
        string.format("id=%s\nversion=%s\n", spec.id, spec.version or "unknown"))

    if not probe(ctx) then
        raise("Fixture '%s' installed but verification failed", spec.id)
    end
    return true, "installed at " .. ctx.install_dir
end

function test(id_or_spec, opts)
    opts = opts or {}
    local spec = resolve(id_or_spec)
    if not spec then
        return false, "unknown fixture: " .. tostring(id_or_spec)
    end
    local ctx = context(spec, opts)
    if not probe(ctx) then
        return false, "not installed"
    end
    local tspec = spec.test
    if not tspec then
        return true, "no test defined"
    end
    local cmd = path.join(ctx.install_dir, (spec.binaries or {})[tspec.command]
        and spec.binaries[tspec.command].path or tspec.command)
    local text = nil
    try {
        function ()
            text = tostring(os.iorunv(cmd, table.wrap(tspec.args), {envs = tool_envs(ctx)}))
        end,
        catch {
            function (e)
                text = tostring(e)
            end
        }
    }
    if tspec.expect and not text:find(tspec.expect, 1, true) then
        return false, ("expected '%s', got: %s"):format(tspec.expect, text:trim():sub(1, 120))
    end
    return true, text:trim():sub(1, 100)
end

-- -----------------------------------------------------------------------------
-- Info / list
-- -----------------------------------------------------------------------------

function info(id_or_spec)
    local spec = resolve(id_or_spec)
    if not spec then
        return nil, "unknown fixture: " .. tostring(id_or_spec)
    end
    local ctx = context(spec, {})
    local lines = {}
    local function put(fmt, ...) table.insert(lines, string.format(fmt, ...)) end
    put("Tool      : %s (%s)", spec.name or spec.id, spec.id)
    put("Version   : %s", spec.version or "unknown")
    put("Install   : %s", ctx.install_dir or "-")
    put("Status    : %s", probe(ctx) and "installed" or "not installed")
    return table.concat(lines, "\n")
end

-- Lists the toolchains available to the project: the package recipes in
-- repository/tools/packages plus any registered fixtures.
function list(tools_root)
    if tools_root then
        local pkgs = path.join(tools_root, "repository", "tools", "packages")
        for _, dir in ipairs(os.dirs(path.join(pkgs, "*", "*")) or {}) do
            local id = path.basename(dir)
            local version = "-"
            local recipe = path.join(dir, "xmake.lua")
            if os.isfile(recipe) then
                local body = io.readfile(recipe) or ""
                version = body:match('add_versions%("([^":]+)"')
                    or body:match('add_versions%("[^:]+:([^"]+)"') or "-"
            end
            local home = os.getenv("HOME") or ""
            local installed = os.isdir(path.join(home, ".local/opt", id))
                or (os.getenv("APPDATA") and os.isdir(path.join(os.getenv("APPDATA"), id)))
            print(string.format("  %-16s %-12s %s", id, version,
                installed and "installed" or "not installed"))
        end
    end
end
