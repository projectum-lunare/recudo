add_rules("mode.debug", "mode.release")
add_requires("forge master", {kind = "addon"})

includes("@addon/forge/forge.lua")

target("${TARGET_NAME}")
    add_rules("forge.engine.love")
    add_files("src/**.lua")
