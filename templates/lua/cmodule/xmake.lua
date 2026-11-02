add_rules("mode.debug", "mode.release")
add_requires("recudo master", {kind = "addon"})
add_requires("lua")

includes("@addon/recudo/recudo.lua")

target("${TARGET_NAME}")
    set_kind("shared")
    add_rules("recudo.lua.module")
    add_packages("lua")
    add_files("src/main.c")
