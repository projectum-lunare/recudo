-- Projectum Lunare Recudo
-- Open Watcom v2 Centralized Detection & Environment Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local detect_sdk = import("detect.sdk", {rootdir = path.join(os.scriptdir(), "..")})

-- Find root SDK directory for Open Watcom
function find_sdk(env_name, opt)
    opt = opt or {}
    opt.fallbacks = opt.fallbacks or "C:\\WATCOM"
    return detect_sdk.find(opt.sdk_name or "watcom", env_name or "WATCOM", opt)
end

-- Resolve the host binary directory (binl64, binl, binnt64, binnt) containing owcc/wcl386
function find_bindir(sdkdir)
    if not sdkdir or not os.isdir(sdkdir) then
        return nil
    end

    local candidate_subdirs = {"binl64", "binl", "binnt64", "binnt"}
    for _, sub in ipairs(candidate_subdirs) do
        local dir = path.join(sdkdir, sub)
        if os.isdir(dir) then
            local owcc = path.join(dir, "owcc")
            local owcc_exe = path.join(dir, "owcc.exe")
            local wcl = path.join(dir, "wcl386")
            local wcl_exe = path.join(dir, "wcl386.exe")
            if os.isfile(owcc) or os.isfile(owcc_exe) or os.isfile(wcl) or os.isfile(wcl_exe) then
                return dir
            end
        end
    end

    -- Fallback to the first existing directory among candidates if tools aren't named standardly
    for _, sub in ipairs(candidate_subdirs) do
        local dir = path.join(sdkdir, sub)
        if os.isdir(dir) then
            return dir
        end
    end

    return nil
end

-- Resolve supplementary tool paths (binw, binp) for DOS extender tools and wlink helpers
function find_tool_paths(sdkdir)
    local pathes = {}
    if not sdkdir or not os.isdir(sdkdir) then
        return pathes
    end

    local bindir = find_bindir(sdkdir)
    if bindir then
        table.insert(pathes, bindir)
    end

    local binw = path.join(sdkdir, "binw")
    if os.isdir(binw) then
        table.insert(pathes, binw)
    end

    local binp = path.join(sdkdir, "binp")
    if os.isdir(binp) then
        table.insert(pathes, binp)
    end

    return pathes
end

-- Build standard environment variables required by Open Watcom v2 compilers and linkers
function get_env(sdkdir, target_sys)
    if not sdkdir then
        return {}
    end

    local bindir = find_bindir(sdkdir)
    local pathes = find_tool_paths(sdkdir)
    if os.getenv("PATH") then
        table.insert(pathes, os.getenv("PATH"))
    end

    local inc_base = path.join(sdkdir, "h")
    local inc_target = (target_sys == "os2v2") and path.join(sdkdir, "h/os2") or path.join(sdkdir, "h/dos")

    return {
        WATCOM = sdkdir,
        EDPATH = path.join(sdkdir, "eddat"),
        PATH = table.concat(pathes, path.envsep()),
        INCLUDE = inc_base .. path.envsep() .. inc_target
    }
end

-- Check if Open Watcom SDK is available and has working binaries
function is_available(env_name, opt)
    local sdkdir = find_sdk(env_name, opt)
    if not sdkdir or not os.isdir(sdkdir) then
        return false
    end

    local bindir = find_bindir(sdkdir)
    if not bindir then
        return false
    end

    local owcc = path.join(bindir, "owcc")
    local owcc_exe = path.join(bindir, "owcc.exe")
    local wcl = path.join(bindir, "wcl386")
    local wcl_exe = path.join(bindir, "wcl386.exe")
    return os.isexec(owcc) or os.isfile(owcc_exe) or os.isexec(wcl) or os.isfile(wcl_exe)
end
