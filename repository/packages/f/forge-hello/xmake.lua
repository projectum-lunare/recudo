set_kind("library", {headeronly = true})
set_homepage("https://github.com/projectum-lunare/forge")
set_description("Example pure Lua module installed by Forge")
set_license("MPL-2.0")

target("forge.hello")
    add_rules("forge.lua.module")
    add_files("src/hello.lua")
