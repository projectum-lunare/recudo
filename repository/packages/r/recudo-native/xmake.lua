set_homepage("https://github.com/projectum-lunare/recudo")
set_description("Example native Lua module installed by Recudo")
set_license("MPL-2.0")
add_deps("lua")

target("recudo.native")
    add_rules("recudo.lua.module")
    add_files("src/native.c")
