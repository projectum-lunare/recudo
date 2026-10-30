package("forge-hello")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/projectum-lunare/forge")
    set_description("Example pure Lua module installed by Forge")
    set_license("MPL-2.0")
    set_sourcedir(path.join(os.scriptdir(), "src"))

    on_install(function (package)
        import("lua.package", {alias = "lua_package"}).install(package, {
            modules = {
                ["forge.hello"] = "hello.lua"
            }
        })
    end)

    on_fetch(function (package, opt)
        return import("lua.package", {alias = "lua_package"}).fetch(package, opt)
    end)
