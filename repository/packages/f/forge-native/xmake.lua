set_homepage("https://github.com/projectum-lunare/forge")
set_description("Example native Lua module installed by Forge")
set_license("MPL-2.0")
add_deps("lua")

target("forge.native")
    add_rules("forge.lua.module")
    add_files("src/native.c")
