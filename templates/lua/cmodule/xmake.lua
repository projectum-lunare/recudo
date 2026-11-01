add_rules("mode.debug", "mode.release")
add_requires("forge master", {kind = "addon"})
add_requires("lua")

includes("@addon/forge/forge.lua")

target("${TARGET_NAME}")
    set_kind("shared")
    add_rules("forge.lua.module")
    add_packages("lua")
    add_files("src/main.c")
