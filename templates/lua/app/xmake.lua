add_rules("mode.debug", "mode.release")
add_requires("forge master", {kind = "addon"})

includes("@addon/forge/forge.lua")

target("${TARGET_NAME}")
    add_rules("forge.lua.app")
    add_files("src/main.lua")
