add_rules("mode.debug", "mode.release")
add_requires("recudo master", {kind = "addon"})

includes("@addon/recudo/recudo.lua")

target("${TARGET_NAME}")
    add_rules("recudo.engine.amulet")
    add_files("src/**.lua")
