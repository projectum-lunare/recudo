package("forge-native")
    set_homepage("https://github.com/projectum-lunare/forge")
    set_description("Example native Lua module installed by Forge")
    set_license("MPL-2.0")
    set_sourcedir(path.join(os.scriptdir(), "src"))
    -- Link mode comes from the project: xmake f --kind=static|shared.
    add_deps("lua")

    on_install(function (package)
        import("lua.package", {alias = "lua_package"}).install(package, {
            modules = {
                ["forge.native"] = "native.c"
            }
        })
    end)
