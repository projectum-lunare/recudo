set_kind("library", {headeronly = true})
set_homepage("https://github.com/projectum-lunare/recudo")
set_description("Example pure Lua module installed by Recudo")
set_license("MPL-2.0")

target("recudo.hello")
    add_rules("recudo.lua.module")
    add_files("src/hello.lua")
