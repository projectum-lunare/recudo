-- Projectum Lunare Recudo - Toolchain Package: AmigaOS GCC (m68k)
-- Bebbo GCC 16.2 + NDK 3.2 + libnix for AmigaOS Classic. A single upstream
-- tarball from the AmigaPorts releases.

package("amigaos-gcc")
    set_homepage("https://github.com/AmigaPorts/m68k-amigaos-gcc")
    set_description("m68k-amigaos GCC cross-compiler, NDK 3.2 and libnix for AmigaOS Classic (m68k)")

    add_urls("https://github.com/AmigaPorts/m68k-amigaos-gcc/releases/download/v$(version)/m68k-amigaos-gcc-$(version)-x86_64-linux.tar.xz")
    add_versions("16.2-rc16", "b1f55d2e754065e5c294a21b6178bf88cf447bcf2d0c0e36a78821fb74844282")

    on_load(function (package)
        package:addenv("PATH", "bin")
        package:addenv("AMIGAOS_GCC", ".")
        package:addenv("AMIGA_SDK", ".")     -- older detection paths
        package:addenv("AMIGAOS_SDK", ".")
    end)

    on_install("linux", function (package)
        local tree = import("toolchain_tree")

        local installdir = package:installdir()
        os.mkdir(installdir)
        tree.copy_tree(tree.descend(os.curdir()), installdir)
        tree.make_executable(path.join(installdir, "bin"))

        assert(os.isfile(path.join(installdir, "bin", "m68k-amigaos-gcc")),
            "m68k-amigaos-gcc missing after install")

        tree.mirror_to(installdir, "amigaos-gcc")
    end)

    on_test("linux", function (package)
        local tree = import("toolchain_tree")
        local gcc = path.join(package:installdir(), "bin", "m68k-amigaos-gcc")
        assert(os.isfile(gcc), "m68k-amigaos-gcc missing after install")
        local text = tree.run_capture(gcc, {"-dumpversion"})
        assert(text:find("16", 1, true), "unexpected version: " .. text:sub(1, 60))
    end)

package_end()
