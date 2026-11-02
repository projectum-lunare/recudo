-- Projectum Lunare Recudo
-- Cross-Platform SDK Detection Module Alias

local detect = import("detect.sdk", {rootdir = os.scriptdir()})
local detect_watcom = import("detect.watcom", {rootdir = os.scriptdir()})

function find(name, env_name, opt)
    return detect.find(name, env_name, opt)
end

function exists(name, env_name, opt)
    return detect.exists(name, env_name, opt)
end

watcom = detect_watcom
