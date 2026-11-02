package("recudo-hello")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/projectum-lunare/recudo")
    set_description("Example pure Lua module installed by Recudo")
    set_license("MPL-2.0")
    set_sourcedir(path.join(os.scriptdir(), "../../../../packages/r/recudo-hello"))

    on_fetch(function (package, opt)
        if opt and opt.system then
            return false
        end
        local manifest = path.join(package:installdir({readonly = true}), "share/recudo/lua-modules.lua")
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
