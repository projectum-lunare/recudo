task("platform-info")
    set_menu {
        usage = "xmake platform-info",
        description = "Show detected compiler, architecture, and platform capabilities",
    }
    on_run(function ()
        import("core.project.config")
        print("========================================")
        print(" Projectum Lunare Forge Platform Info")
        print("========================================")
        print("Host OS:      " .. os.host())
        print("Host Arch:    " .. os.arch())
        print("Config Plat:  " .. tostring(config.get("plat") or os.host()))
        print("Config Arch:  " .. tostring(config.get("arch") or os.arch()))
        print("Toolchain:    " .. tostring(config.get("toolchain") or "default"))
        print("========================================")
    end)
