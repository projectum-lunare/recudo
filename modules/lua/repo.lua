-- Publish repository/packages as an xmake package repository.
-- A recipe that declares a target is wrapped in package() for the loader.
-- A recipe that already calls package() is copied through.

local ROOT = path.directory(path.directory(os.scriptdir()))

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
                os.mkdir(outdir)
                local text = io.readfile(script) or ""
                if text:find("package%s*%(", 1) then
                    os.cp(script, path.join(outdir, "xmake.lua"))
                else
                    local homepage = text:match('set_homepage%s*%(%s*"([^"]*)"')
                    local description = text:match('set_description%s*%(%s*"([^"]*)"')
                    local license = text:match('set_license%s*%(%s*"([^"]*)"')
                    local headeronly = text:find("headeronly%s*=%s*true") ~= nil
                    local deps = {}
                    for dep in text:gmatch('add_deps%s*%(%s*"([^"]*)"') do
                        table.insert(deps, dep)
                    end
                    local lines = {"package(" .. string.format("%q", name) .. ")"}
                    if headeronly then
                        table.insert(lines, '    set_kind("library", {headeronly = true})')
                    end
                    if homepage then
                        table.insert(lines, "    set_homepage(" .. string.format("%q", homepage) .. ")")
                    end
                    if description then
                        table.insert(lines, "    set_description(" .. string.format("%q", description) .. ")")
                    end
                    if license then
                        table.insert(lines, "    set_license(" .. string.format("%q", license) .. ")")
                    end
                    local sourcedir = path.relative(pkgdir, outdir)
                    table.insert(lines, "    set_sourcedir(path.join(os.scriptdir(), " .. string.format("%q", sourcedir) .. "))")
                    for _, dep in ipairs(deps) do
                        table.insert(lines, "    add_deps(" .. string.format("%q", dep) .. ")")
                    end
                    table.insert(lines, "")
                    table.insert(lines, "    on_fetch(function (package, opt)")
                    table.insert(lines, "        if opt and opt.system then")
                    table.insert(lines, "            return false")
                    table.insert(lines, "        end")
                    table.insert(lines, "        local manifest = path.join(package:installdir({readonly = true}), \"share/forge/lua-modules.lua\")")
                    table.insert(lines, "        if not os.isfile(manifest) then")
                    table.insert(lines, "            return false")
                    table.insert(lines, "        end")
                    table.insert(lines, "        local stamp = os.mtime(manifest)")
                    table.insert(lines, "        local src = package:sourcedir()")
                    table.insert(lines, "        if src and os.isfile(path.join(src, \"xmake.lua\")) and os.mtime(path.join(src, \"xmake.lua\")) > stamp then")
                    table.insert(lines, "            return false")
                    table.insert(lines, "        end")
                    table.insert(lines, "        if src then")
                    table.insert(lines, "            for _, source in ipairs(os.files(path.join(src, \"src\", \"**\"))) do")
                    table.insert(lines, "                if os.mtime(source) > stamp then")
                    table.insert(lines, "                    return false")
                    table.insert(lines, "                end")
                    table.insert(lines, "            end")
                    table.insert(lines, "        end")
                    table.insert(lines, "    end)")
                    table.insert(lines, "")
                    table.insert(lines, "    on_install(function (package)")
                    table.insert(lines, '        import("lua.module").build(package)')
                    table.insert(lines, "    end)")
                    io.writefile(path.join(outdir, "xmake.lua"), table.concat(lines, "\n") .. "\n")
                end
            end
        end
    end
    if found then
        return outroot
    end
end
