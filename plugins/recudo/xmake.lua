-- Projectum Lunare Recudo
-- Reference: https://xmake.io/guide/extensions/addons/introduction.html

local menu_conf = {
    usage = "xmake recudo [options] [target] [build_target]",
    description = "Projectum Lunare Recudo - Cross-Compilation, Toolchain & Lua Engine",
    options = {
        {'c', "clean",         "k",  nil,    "Clean reconfigure before build."},
        {'a', "arch",          "kv", nil,    "Target architecture (e.g. x86_64, arm64, i386, m68k, etc.)."},
        {'r', "runtime",       "kv", nil,    "Lua runtime interpreter for repl (e.g. lua, luajit)."},
        {'e', "eval",          "kv", nil,    "Execute Lua code snippet in project environment."},
        {'t', "template",      "kv", "app",  "Project template for create action: app, module, cmodule, love, amulet, love-compat, amulet-compat."},
        {nil, "interpreter",   "kv", nil,    "Path to custom Lua interpreter binary."},
        {nil, "no-isolate",    "k",  nil,    "Do not isolate build directory into build/<target>."},
        {nil, "export-env",    "k",  nil,    "Export LUA_PATH and LUA_CPATH into .env file."},
        {nil, "json",          "k",  nil,    "Output environment paths in JSON format."},
        {nil, "fish",          "k",  nil,    "Output environment paths for fish shell."},
        {},
        {nil, "target",        "v",  "list", "Target platform or action: amiga, atari, kolibri, dos, os2, wince, freebsd, openbsd, netbsd, dragonflybsd, posix, all, list, env, repl, create"},
        {nil, "build_target",  "v",  nil,    "Specific project target to build, or project name for create action."},
        {nil, "extra_args",    "vs", nil,    "Extra arguments for actions (e.g. template name)."}
    }
}

task("recudo")
    set_category("plugin")
    set_menu(menu_conf)
    on_run("main")
