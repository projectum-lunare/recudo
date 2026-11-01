add_rules("mode.debug", "mode.release")
add_requires("forge master", {kind = "addon"})
add_requires("lua-compat-5.3")

includes("@addon/forge/forge.lua")

target("${TARGET_NAME}")
    add_rules("forge.engine.love")
    add_packages("lua-compat-5.3")
    add_files("src/**.lua")
