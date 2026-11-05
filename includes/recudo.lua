-- Projectum Lunare Recudo - Unified Build, Toolchain & Cross-Compilation Addon
-- Automatically exports platforms, rules, toolchains, modules and canonical architectures

-- Resolve recudo addon root directory.
-- A recipe build includes this file, so scriptdir is the addon includes
-- directory. RECUDO_LUA_ROOT covers a run where the text is prepended to the
-- recipe and scriptdir would otherwise be the recipe directory.
local rootdir = getenv("RECUDO_LUA_ROOT")
if not rootdir or rootdir == "" then
    rootdir = path.directory(os.scriptdir())
end

-- import() is not available while this file is loading. The include publishes
-- the catalog helpers, then _dismiss() removes them from the project script.
includes(path.join(rootdir, "modules/catalog.lua"))
set_defaultarchs(table.unpack(default_archs()))
local plat_is_static = is_static
_dismiss()

-- Register platform definitions, addon modules and the local Lua package repository
add_platformdirs(path.join(rootdir, "platforms"))
add_moduledirs(path.join(rootdir, "modules"))
add_moduledirs(path.join(rootdir, "repository/tools/modules"))

-- One link mode for the whole graph. `xmake f --kind=shared` builds shared
-- libraries. `xmake f --kind=static` (the default) builds archives. Platforms
-- that cannot dlopen stay static even when the project asks for shared.
-- The wildcard is a DEFAULT, not an override: packages explicitly configured
-- by the consumer (e.g. add_requires("lua", {configs = {shared = true}}))
-- keep their own settings, so the addon never stomps explicit intent.
local link_plat = get_config("plat") or os.host()
local link_kind = get_config("kind") or "static"
local link_shared = link_kind == "shared"
if plat_is_static(link_plat) then
    link_shared = false
end
add_requireconfs("**", {configs = {shared = link_shared}})

-- 4. Register native rules, toolchains and CLI plugins
includes(path.join(rootdir, "rules/**/xmake.lua"))
includes(path.join(rootdir, "toolchains/*.lua"))
includes(path.join(rootdir, "plugins/*/xmake.lua"))

-- Packages are installed before target on_load, so the repository has to be
-- registered while the project script is still loading. on_load refreshes it
-- for the next configure.
-- Toolchain packages (recudo-tools): the xmake-native provisioning channel
if getenv("RECUDO_LUA_PROJECT") ~= "1" and os.isdir(path.join(rootdir, "repository", "tools")) then
    add_repositories("recudo-tools repository/tools", {rootdir = rootdir})
end

if getenv("RECUDO_LUA_PROJECT") ~= "1" and os.isdir(path.join(rootdir, "repository", "repo")) then
    add_repositories("recudo-lua repository/repo", {rootdir = rootdir})
end

if getenv("RECUDO_LUA_PROJECT") ~= "1" then
    target("__recudo_lua_repo")
        set_kind("phony")
        set_default(false)
        on_load(function ()
            local repodir = import("lua.repo").publish()
            if repodir then
                import("core.package.repository").add("recudo-lua", repodir)
                import("core.package.repository").load("recudo-lua", repodir)
            end
        end)
end

-- The recipe is an ordinary xmake project. Its package metadata is ignored here.
-- Inside a rule or toolchain the real interface stays in place. At the root,
-- add_deps("lua") is the package dependency.
if getenv("RECUDO_LUA_PROJECT") == "1" then
    function set_homepage() end
    function set_description() end
    function set_license() end

    local set_kind_shim
    set_kind_shim = function (kind, opt)
        if interp_get_scopekind() == nil then
            return
        end
        set_kind = nil
        local real = set_kind
        set_kind = set_kind_shim
        real(kind, opt)
    end
    set_kind = set_kind_shim

    local add_deps_shim
    add_deps_shim = function (name, opt)
        if interp_get_scopekind() == nil then
            if type(name) == "string" then
                add_requires(name)
            end
            return
        end
        add_deps = nil
        local real = add_deps
        add_deps = add_deps_shim
        real(name, opt)
    end
    add_deps = add_deps_shim
end

