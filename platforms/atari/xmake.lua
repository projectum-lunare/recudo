-- Projectum Lunare Forge
-- Platform: Atari ST / FreeMiNT (m68k)

platform("atari")
    set_os("atarist")
    set_hosts("linux", "windows", "macosx", "bsd")
    set_archs("m68k")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("binary", "$(name).tos")

    set_toolchains("atarist")
