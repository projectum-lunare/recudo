-- Projectum Lunare Recudo - Tool Patch DSL
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- Declarative patch contract for compiler tools (vbcc, evc3, watcom...).
--
-- One setup() describes the toolchain dimensions the package cares about -
-- platform and semver applicability - and the module resolves the current
-- build against it, applying the matching compatibility patch:
--
--   local tc = import("@addon.recudo.tool.patch").setup(package, {
--       evc3 = {                                 -- key = the xmake toolchain name
--           toolchain = "recudo.toolchain.evc3", -- the nested build rule
--           c = {"89"},                          -- C standards the compiler supports
--           patch = "patches/evc3.patch",        -- version-agnostic patch
--       },
--       vbcc = {                                 -- opt-in: xmake f --toolchain=vbcc
--           toolchain = "recudo.toolchain.vbcc",
--           c = {"89"},
--           patches = {
--               {versions = ">=5.1.0 <5.2.0", patch = "patches/vbcc-5.1.patch"},
--               {versions = ">=5.4.4 <5.5.0", patch = "patches/vbcc-5.4.patch"},
--               -- combinations: toolchain x platform
--               {platforms = "kolibri", versions = ">=5.4.0",
--                patch = "patches/vbcc-kolibri.patch"},
--           },
--       },
--   })
--
--   tc.vbcc.enabled       -> resolved switch (boolean) for the nested build
--   tc.vbcc.toolchain     -> the declared rule name, for the nested build
--   tc.vbcc.c             -> the C standards the compiler supports
--   tc.patched.vbcc       -> true when the matching patch was applied
--   tc.tools              -> the declared tools, in application order
--   tc.addon              -> true when any enabled tool drives a build rule
--                            (the nested build loads the recudo addon only
--                            when a rule will actually be applied)
--
-- The keys are the xmake toolchain names: a tool is active when its
-- toolchain drives the current build - either the platform's catalog
-- default (set_toolchains in the platform definition) or the consumer's
-- explicit choice (xmake f --toolchain=vbcc).
--
-- Each patch entry carries its own conditions (platforms and/or semver
-- versions); every declared dimension must match (AND) and the first
-- matching entry wins.
--
-- Contract:
--   - a tool is active when its xmake toolchain drives the current build;
--     the compiler choice belongs to the build system, never to package
--     configs
--   - a selected tool with NO patch entry covering the package version is a
--     hard error: a silently degraded build (broken hex float literals...)
--     is a trap, not a fallback
--   - a tool whose only job is compiling (no source fixes needed) declares
--     no patches and applies nothing (patched stays nil)
--   - C standard support is a property of the compiler, declared here as
--     the c list - never inferred from the platform
--
-- Runs at on_install time ON PURPOSE: the definition scope has no
-- is_toolchain() predicate and patches must land before the nested build
-- is generated.

-- a tool is active when its xmake toolchain drives the current build: the
-- platform's catalog default or the consumer's --toolchain both surface
-- here. The match name is the declared toolchain's identity; entries
-- without one (patch-only) match by their key, following the convention of
-- naming them after the toolchain/platform they serve.
local function _package_uses(package, key, conf)
    local name = conf.toolchain and conf.toolchain:match("[^%.]+$") or key
    for _, toolchain in ipairs(table.wrap(package:toolchains() or {})) do
        if toolchain:name() == name then
            return true
        end
    end
    return false
end

-- the patch entry covering this package version and platform, or nil.
-- Every declared dimension must match (AND): platforms (is_plat) and/or
-- versions (semver range); an entry without conditions always matches.
local function _matching_patch(package, conf)
    local semver = import("core.base.semver")
    local patches = conf.patches
    if not patches and conf.patch then
        patches = {{patch = conf.patch}}
    end
    local version = package:version():shortstr()
    for _, entry in ipairs(table.wrap(patches)) do
        if entry.platforms and not package:is_plat(table.unpack(table.wrap(entry.platforms))) then
            -- combinations: this entry targets other platforms
            -- (e.g. toolchain x platform)
        elseif entry.versions and not semver.satisfies(version, entry.versions) then
            -- this entry targets other versions
        else
            local candidate = path.join(package:scriptdir(), entry.patch)
            if os.isfile(candidate) then
                return candidate
            end
            -- the conditions matched but the file is gone: author bug,
            -- raised upstream with a clean message instead of git's raw one
            return nil
        end
    end
end

function setup(package, tools)
    tools = tools or {}
    local resolved = {patched = {}}

    -- deterministic order: patches of different tools touch different
    -- files, but fixed order keeps installs reproducible
    local names = {}
    for tool in pairs(tools) do
        table.insert(names, tool)
    end
    table.sort(names)
    resolved.tools = names

    for _, key in ipairs(names) do
        local conf = tools[key] or {}
        local use = _package_uses(package, key, conf)
        resolved[key] = {enabled = use, toolchain = conf.toolchain, c = conf.c}
        if use then
            if conf.patch or conf.patches then
                local patchfile = _matching_patch(package, conf)
                -- the package DECLARED patches for this entry: one of them
                -- must cover the package version - a gap is an author bug,
                -- not a fallback
                if not patchfile then
                    raise("recudo: no %s patch covers %s %s on %s", key, package:name(), package:version_str(), package:plat())
                end
                import("devel.git").apply(patchfile)
                resolved.patched[key] = true
            end
            -- an entry declared without patches applies nothing
            -- (patched[key] stays nil - not applicable)
        end
    end

    -- does any enabled tool drive a build rule? the nested build only
    -- needs the recudo addon when a rule will actually be applied
    for _, key in ipairs(names) do
        local t = resolved[key]
        if t.enabled and t.toolchain then
            resolved.addon = true
            break
        end
    end
    return resolved
end
