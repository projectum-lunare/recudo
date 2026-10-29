-- solo - Physical I/O, System Foundations & Hardware Abstractions
-- Platform: Microsoft Windows CE

platform("wince")
    set_os("windows_ce")
    set_hosts("linux", "windows", "macosx", "bsd")
    set_archs("arm", "mips", "ppc", "sh3", "sh4", "x86")

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("binary", "$(name).exe")

    set_toolchains("evc3")
