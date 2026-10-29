-- Projectum Lunare Forge
-- Platform: FreeBSD
-- Official architecture source: https://www.freebsd.org/where/

platform("freebsd")
    set_os("freebsd")
    set_hosts("linux", "windows", "macosx", "bsd", "freebsd")
    set_archs(
        "x86_64", "i386", "arm64", "armv7",
        "ppc", "ppc64", "ppc64le", "ppcspe", "riscv64"
    )

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("shared", "lib$(name).so")
    set_formats("symbol", "$(name).sym")

    set_installdir("/usr/local")

    set_toolchains("freebsd")
