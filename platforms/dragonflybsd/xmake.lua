-- Projectum Lunare Forge
-- Platform: DragonFly BSD
-- Official architecture source: https://www.dragonflybsd.org/download/

platform("dragonflybsd")
    set_os("dragonfly")
    set_hosts("linux", "windows", "macosx", "bsd", "dragonflybsd", "dragonfly")
    set_archs("x86_64")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("shared", "lib$(name).so")
    set_formats("symbol", "$(name).sym")

    set_installdir("/usr/local")

    set_toolchains("dragonflybsd")

platform("dragonfly")
    set_os("dragonfly")
    set_hosts("linux", "windows", "macosx", "bsd", "dragonflybsd", "dragonfly")
    set_archs("x86_64")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("shared", "lib$(name).so")
    set_formats("symbol", "$(name).sym")

    set_installdir("/usr/local")

    set_toolchains("dragonflybsd")
