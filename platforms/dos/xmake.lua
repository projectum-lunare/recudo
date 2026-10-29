-- Projectum Lunare Forge
-- Platform: MS-DOS 32-bit Protected Mode

platform("dos")
    set_os("dos")
    set_hosts("linux", "windows", "macosx", "bsd")
    set_archs("i386")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("binary", "$(name).exe")

    set_toolchains("watcom")
