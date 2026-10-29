-- Projectum Lunare Forge
-- Reference: https://xmake.io/guide/extensions/addons/introduction.html

local menu_conf = {
    usage = "xmake forge [target] [options]",
    description = "Projectum Lunare Forge - Cross-Compilation & Toolchain Engine",
    options = {
        {'c', "clean",   "k", nil, "Clean reconfigure before build."},
        {nil, "target",  "v", "list", "Target platform: amiga, atari, kolibri, dos, os2, posix, all, list"}
    }
}

task("forge")
    set_category("plugin")
    set_menu(menu_conf)
    on_run("main")

-- Backward compatibility alias
task("vintage")
    set_category("plugin")
    set_menu(menu_conf)
    on_run("main")
