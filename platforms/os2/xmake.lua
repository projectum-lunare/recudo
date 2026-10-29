-- Projectum Lunare Forge
-- Platform: OS/2 32-bit Warp

platform("os2")
    set_os("os2")
    set_hosts("linux", "windows", "macosx", "bsd")
    set_archs("i386")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("binary", "$(name).exe")

    set_toolchains("watcom")
