-- Projectum Lunare Forge
-- Cross-Platform SDK Detection Module
-- Supports Unix ($HOME/.local/opt/<sdk>) and Windows (%APPDATA%/<sdk>, %LOCALAPPDATA%/<sdk>)

function find(name, env_name, opt)
    opt = opt or {}

    -- 1. Explicit environment variable override
    if env_name then
        local env_val = os.getenv(env_name)
        if env_val and #env_val > 0 then
            return path.normalize(env_val)
        end
    end

    -- 2. Candidate paths
    local candidates = {}

    -- Unix standard: ~/.local/opt/<name>
    local home = os.getenv("HOME")
    if home then
        table.insert(candidates, path.join(home, ".local/opt", name))
    end

    -- Windows standard: %APPDATA%/<name> and %LOCALAPPDATA%/<name>
    local appdata = os.getenv("APPDATA")
    if appdata then
        table.insert(candidates, path.join(appdata, name))
    end
    local localappdata = os.getenv("LOCALAPPDATA")
    if localappdata then
        table.insert(candidates, path.join(localappdata, name))
    end

    -- Custom fallbacks (e.g. C:\WATCOM)
    if opt.fallbacks then
        for _, fb in ipairs(table.wrap(opt.fallbacks)) do
            table.insert(candidates, fb)
        end
    end

    -- Return first directory that exists on disk
    for _, dir in ipairs(candidates) do
        if os.isdir(dir) then
            return path.normalize(dir)
        end
    end

    -- If not yet installed, return the canonical path for host OS
    if os.host() == "windows" and appdata then
        return path.normalize(path.join(appdata, name))
    elseif home then
        return path.normalize(path.join(home, ".local/opt", name))
    end
    return candidates[1]
end

function exists(name, env_name, opt)
    local p = find(name, env_name, opt)
    return p ~= nil and os.isdir(p)
end
