-- Publish repository/packages as an xmake package repository.
-- A recipe that declares a target is wrapped in package() for the loader.
-- A recipe that already calls package() is copied through.

import("template", {rootdir = path.join(os.scriptdir(), "..")})

local ROOT = path.directory(path.directory(os.scriptdir()))

local function q(value)
    return string.format("%q", value)
end

-- The fetch and install bodies are the same for every recipe. Only the
-- package header changes, so that header is the template.
local render_recipe = template.compile([[package(<%= q(name) %>)
<% if headeronly then %>    set_kind("library", {headeronly = true})
<% end %><% if homepage then %>    set_homepage(<%= q(homepage) %>)
<% end %><% if description then %>    set_description(<%= q(description) %>)
<% end %><% if license then %>    set_license(<%= q(license) %>)
<% end %>    set_sourcedir(path.join(os.scriptdir(), <%= q(sourcedir) %>))
<% for _, dep in ipairs(deps) do %>    add_deps(<%= q(dep) %>)
<% end %>
    on_fetch(function (package, opt)
        if opt and opt.system then
            return false
        end
        local manifest = path.join(package:installdir({readonly = true}), "share/forge/lua-modules.lua")
        if not os.isfile(manifest) then
            return false
        end
        local stamp = os.mtime(manifest)
        local src = package:sourcedir()
        if src and os.isfile(path.join(src, "xmake.lua")) and os.mtime(path.join(src, "xmake.lua")) > stamp then
            return false
        end
        if src then
            for _, source in ipairs(os.files(path.join(src, "src", "**"))) do
                if os.mtime(source) > stamp then
                    return false
                end
            end
        end
    end)

    on_install(function (package)
        import("lua.module").build(package)
    end)
]])

local function metadata(text)
    local deps = {}
    for dep in text:gmatch('add_deps%s*%(%s*"([^"]*)"') do
        table.insert(deps, dep)
    end
    return {
        homepage = text:match('set_homepage%s*%(%s*"([^"]*)"'),
        description = text:match('set_description%s*%(%s*"([^"]*)"'),
        license = text:match('set_license%s*%(%s*"([^"]*)"'),
        headeronly = text:find("headeronly%s*=%s*true") ~= nil,
        deps = deps
    }
end

function publish()
    local root = ROOT
    local packages_root = path.join(root, "repository", "packages")
    if not os.isdir(packages_root) then
        return nil
    end
    local outroot = path.join(root, "repository", "repo")
    os.tryrm(outroot)
    local found = false
    for _, letterdir in ipairs(os.dirs(path.join(packages_root, "*"))) do
        for _, pkgdir in ipairs(os.dirs(path.join(letterdir, "*"))) do
            local script = path.join(pkgdir, "xmake.lua")
            if os.isfile(script) then
                found = true
                local name = path.filename(pkgdir)
                local outdir = path.join(outroot, "packages", path.filename(letterdir), name)
                if not os.isdir(outdir) then
                    os.mkdir(outdir)
                end
                local text = io.readfile(script) or ""
                if text:find("package%s*%(", 1) then
                    os.cp(script, path.join(outdir, "xmake.lua"))
                else
                    local info = metadata(text)
                    info.q = q
                    info.name = name
                    info.sourcedir = path.relative(pkgdir, outdir)
                    io.writefile(path.join(outdir, "xmake.lua"), render_recipe(info))
                end
            end
        end
    end
    if found then
        return outroot
    end
end
