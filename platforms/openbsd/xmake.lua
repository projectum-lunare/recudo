-- Projectum Lunare Forge
-- Platform: OpenBSD
-- Official architecture source: https://www.openbsd.org/faq/faq4.html#Download

platform("openbsd")
    set_os("openbsd")
    set_hosts("linux", "windows", "macosx", "bsd", "openbsd")
    set_archs(
        "x86_64", "i386", "arm64", "armv7",
        "alpha", "hppa", "m88k", "mips64",
        "ppc", "ppc64", "riscv64", "sh4", "sparc64"
    )

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("shared", "lib$(name).so")
    set_formats("symbol", "$(name).sym")

    set_installdir("/usr/local")

    set_toolchains("openbsd")
