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

-- 5. Auto-bind vintage compiler rules into standard C/C++ build graph
rule("forge.platform.dispatcher")
    on_load(function (target)
        if (target:is_plat("dos", "os2") or target:toolchain("watcom")) and not target:rule("forge.watcom") then
            import("core.project.project")
            local r = project.rule("forge.watcom")
            if r then
                target:rule_add(r)
                local load_fn = r:script("load")
                if load_fn then load_fn(target) end
            end
        elseif (target:is_plat("wince") or target:toolchain("evc3")) and not target:rule("forge.evc3") then
            import("core.project.project")
            local r = project.rule("forge.evc3")
            if r then
                target:rule_add(r)
                local load_fn = r:script("load")
                if load_fn then load_fn(target) end
            end
        end
    end)

rule("c")
    add_deps("c.build")
    add_deps("utils.inherit.links")
    add_deps("utils.merge.object", "utils.merge.archive")
    add_deps("utils.symbols.extract")
    add_deps("platform.wasm")
    add_deps("platform.windows")
    add_deps("linker")
    add_deps("forge.platform.dispatcher")

rule("c++")
    add_deps("c++.build")
    add_deps("utils.inherit.links")
    add_deps("utils.merge.object", "utils.merge.archive")
    add_deps("utils.symbols.extract")
    add_deps("platform.wasm")
    add_deps("platform.windows")
    add_deps("linker")
    add_deps("forge.platform.dispatcher")
