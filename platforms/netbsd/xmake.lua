-- Projectum Lunare Forge
-- Platform: NetBSD
-- Official architecture source: https://wiki.netbsd.org/ports/

platform("netbsd")
    set_os("netbsd")
    set_hosts("linux", "windows", "macosx", "bsd", "netbsd")
    set_archs(
        "x86_64", "i386", "arm", "arm64",
        "alpha", "hppa", "ia64", "m68k", "m68010",
        "mips", "mips64", "mipseb", "mipsel",
        "ppc", "ppc64", "riscv32", "riscv64",
        "sh3", "sh3eb", "sh3el",
        "sparc", "sparc64", "vax"
    )

    set_formats("static", "lib$(name).a")
    set_formats("object", "$(name).o")
    set_formats("shared", "lib$(name).so")
    set_formats("symbol", "$(name).sym")

    set_installdir("/usr/pkg")

    set_toolchains("envs", "gcc", "clang", "yasm", "nasm", "fasm", "go", "rust", "gfortran", "zig", "dotnet")
