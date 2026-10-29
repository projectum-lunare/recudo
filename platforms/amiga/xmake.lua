-- Projectum Lunare Forge
-- Platform: AmigaOS Classic (m68k)

platform("amiga")
    set_os("amigaos")
    set_hosts("linux", "windows", "macosx", "bsd")
    set_archs("m68k", "m68000", "m68020", "m68030", "m68040", "m68060")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("binary", "$(name)")

    set_toolchains("amigaos")
