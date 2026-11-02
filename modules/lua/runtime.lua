-- Projectum Lunare Recudo - Lua Runtime & Package Orchestration Helper
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- Configures runtime dependencies, version constraints, and addon linkages for a package
function setup(package, opt)
    if type(opt) == "string" then
        if opt == "luajit" or opt == "openresty-luajit" or opt == "lua" then
            opt = {runtime = opt}
        else
            opt = {version = opt}
        end
    end
    opt = opt or {}

    -- Determine supported runtimes
    local supported_runtimes
    if type(opt.runtime) == "table" then
        supported_runtimes = opt.runtime
    elseif type(opt.runtime) == "string" then
        supported_runtimes = {opt.runtime}
    elseif opt.runtimes then
        supported_runtimes = table.wrap(opt.runtimes)
    else
        supported_runtimes = {"lua", "luajit"}
    end

    local default_rt = opt.default or supported_runtimes[1] or "lua"

    -- For packages supporting multiple runtimes, ensure "runtime" config is registered
    -- so Xmake generates separate buildhashes and accepts -f "runtime=..." or configs = {runtime = ...}
    if #supported_runtimes > 1 and package._INFO then
        local configs_defined = package:get("configs")
        if not configs_defined or not table.contains(table.wrap(configs_defined), "runtime") then
            package._INFO:apival_add("configs", "runtime")
            package._INFO:extraconf_set("configs", "runtime", "default", default_rt)
            package._INFO:extraconf_set("configs", "runtime", "values", supported_runtimes)
            package._INFO:extraconf_set("configs", "runtime", "description", "Target Lua runtime implementation")
            package._CONFIGS = nil
            package._CONFIGS_FOR_BUILDHASH = nil
            package._BUILDHASH = nil
        end
    end

    -- Resolve requested runtime
    local req = package.requireinfo and package:requireinfo()
    local req_configs = req and req.configs
    local rt = (package.config and package:config("runtime")) or (req_configs and req_configs.runtime) or default_rt

    if not table.contains(supported_runtimes, rt) then
        raise("Package '%s' does not support runtime '%s'. Supported: %s", package:name(), tostring(rt), table.concat(supported_runtimes, ", "))
    end

    local dep_configs = {}
    if package.config and package:config("shared") ~= nil then
        dep_configs.shared = package:config("shared")
    end
    local dep_opts = not table.empty(dep_configs) and {configs = dep_configs} or {}

    if rt == "luajit" then
        package:add("deps", "luajit", dep_opts)
    elseif rt == "openresty-luajit" then
        package:add("deps", "openresty-luajit", dep_opts)
    elseif rt == "lua" then
        local ver = (package.config and package:config("lua_version")) or opt.version or opt.lua or opt.lua_version
        if ver then
            local semver = import("core.base.semver")
            if not ver:find("[><=]") then
                local v = semver.new(ver)
                if opt.min and v:lt(opt.min) then
                    raise("Package '%s' requires Lua >= %s, but Lua %s was requested", package:name(), opt.min, ver)
                end
                if opt.max and v:gt(opt.max) then
                    raise("Package '%s' requires Lua <= %s, but Lua %s was requested", package:name(), opt.max, ver)
                end
                local constraint = opt.version or opt.lua or opt.lua_version
                if constraint and (constraint:find("<") or constraint:find("<=")) then
                    local max_bound = constraint:match("<=%s*([%d%.]+)") or constraint:match("<%s*([%d%.]+)")
                    if max_bound then
                        local is_strict_less = constraint:find("<%s*" .. max_bound) and not constraint:find("<=%s*" .. max_bound)
                        if is_strict_less and v:ge(max_bound) then
                            raise("Package '%s' only supports Lua %s or LuaJIT, but Lua %s was requested", package:name(), constraint, ver)
                        elseif v:gt(max_bound) then
                            raise("Package '%s' only supports Lua %s or LuaJIT, but Lua %s was requested", package:name(), constraint, ver)
                        end
                    end
                end
            end
            package:add("deps", "lua " .. ver, dep_opts)
        else
            package:add("deps", "lua", dep_opts)
        end
    else
        raise("Package '%s': unsupported Lua runtime '%s'", package:name(), tostring(rt))
    end
    package:add("deps", "recudo master", {kind = "addon"})
end
