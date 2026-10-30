-- Projectum Lunare Forge
-- Reference: https://xmake.io/guide/extensions/addons/introduction.html

local menu_conf = {
    usage = "xmake forge [target] [build_target] [options]",
    description = "Projectum Lunare Forge - Cross-Compilation, Toolchain & Lua Engine",
    options = {
        {'c', "clean",         "k",  nil,    "Clean reconfigure before build."},
        {'a', "arch",          "kv", nil,    "Target architecture (e.g. x86_64, arm64, i386, m68k, etc.)."},
        {nil, "no-isolate",    "k",  nil,    "Do not isolate build directory into build/<target>."},
        {nil, "export-env",    "k",  nil,    "Export LUA_PATH and LUA_CPATH into .env file."},
        {nil, "json",          "k",  nil,    "Output environment paths in JSON format."},
        {nil, "fish",          "k",  nil,    "Output environment paths for fish shell."},
        {},
        {nil, "target",        "v",  "list", "Target platform or action: amiga, atari, kolibri, dos, os2, wince, freebsd, openbsd, netbsd, dragonflybsd, posix, all, list, env"},
        {nil, "build_target",  "v",  nil,    "Specific project target to build (default: all default targets)."}
    }
}

task("forge")
    set_category("plugin")
    set_menu(menu_conf)
    on_run("main")
