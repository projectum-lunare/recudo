-- Projectum Lunare Forge - Unified Build, Toolchain & Cross-Compilation Addon
-- Automatically exports platforms, rules, toolchains, modules and canonical architectures

-- 1. Register canonical default architectures for vintage & BSD platforms
set_defaultarchs(
    "amiga|m68k",
    "atari|m68k",
    "kolibri|i386",
    "dos|i386",
    "os2|i386",
    "wince|arm",
    "freebsd|x86_64",
    "openbsd|x86_64",
    "netbsd|x86_64",
    "dragonflybsd|x86_64",
    "dragonfly|x86_64"
)

-- 2. Resolve forge addon root directory
local rootdir = path.directory(os.scriptdir())

-- 3. Register platform definitions, addon modules and the local Lua package repository
add_platformdirs(path.join(rootdir, "platforms"))
add_moduledirs(path.join(rootdir, "modules"))
if os.isdir(path.join(rootdir, "repository")) then
    add_repositories("forge-lua repository", {rootdir = rootdir})
end

-- One link mode for the whole graph. `xmake f --kind=shared` builds shared
-- libraries. `xmake f --kind=static` (the default) builds archives. Platforms
-- that cannot dlopen stay static even when the project asks for shared.
local link_plat = get_config("plat") or os.host()
local link_kind = get_config("kind") or "static"
local link_shared = link_kind == "shared"
if link_plat == "amiga" or link_plat == "atari" or link_plat == "kolibri"
    or link_plat == "dos" or link_plat == "os2" or link_plat == "wince"
    or link_plat == "wasm" then
    link_shared = false
end
add_requireconfs("**", {override = true, configs = {shared = link_shared}})

-- 4. Register native rules, toolchains and CLI plugins
includes(path.join(rootdir, "rules/**/xmake.lua"))
includes(path.join(rootdir, "toolchains/*.lua"))
includes(path.join(rootdir, "plugins/*/xmake.lua"))

