add_rules("mode.debug", "mode.release")
add_requires("recudo master", {kind = "addon"})
add_requires("lua-compat-5.3")

includes("@addon/recudo/recudo.lua")

target("${TARGET_NAME}")
    add_rules("recudo.engine.love")
    add_packages("lua-compat-5.3")
    add_files("src/**.lua")
