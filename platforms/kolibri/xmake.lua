-- Projectum Lunare Forge
-- Platform: KolibriOS (x86)

platform("kolibri")
    set_os("kolibrios")
    set_hosts("linux", "windows", "macosx", "bsd")
    set_archs("i386")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("binary", "$(name)")

    set_toolchains("kolibrios")
