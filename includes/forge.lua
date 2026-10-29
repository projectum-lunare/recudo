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

-- 3. Register platform definitions and addon modules
add_platformdirs(path.join(rootdir, "platforms"))
add_moduledirs(path.join(rootdir, "modules"))

-- 4. Register native rules, toolchains and CLI plugins
includes(path.join(rootdir, "rules/**/xmake.lua"))
includes(path.join(rootdir, "toolchains/*.lua"))
includes(path.join(rootdir, "plugins/*/xmake.lua"))
