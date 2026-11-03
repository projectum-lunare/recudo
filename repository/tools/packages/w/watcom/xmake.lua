-- Projectum Lunare Recudo - Toolchain Package: Open Watcom v2
-- C/C++ cross-compiler for DOS, OS/2, Win16, Win32 and Linux x86, from the
-- upstream snapshot releases.

package("watcom")
    set_homepage("https://github.com/open-watcom/open-watcom-v2")
    set_description("Open Watcom v2 C/C++ cross-compiler for DOS, OS/2, Win16, Win32 and Linux x86")

    add_urls("https://github.com/open-watcom/open-watcom-v2/releases/download/$(version)-Build/ow-snapshot.tar.xz")
    add_versions("2026-10-01", "e6aa1b1e40ac8bbf97658d2c70fff8a4242d6ca4a1c60806f2baa5317083d4fe")

    on_load(function (package)
        package:addenv("PATH", "binl64")
        package:addenv("PATH", "binl")
        package:addenv("WATCOM", ".")
        package:addenv("EDPATH", "eddat")
        package:addenv("INCLUDE", "h")
    end)

    on_install("linux", function (package)
        local tree = import("toolchain_tree")

        local installdir = package:installdir()
        os.mkdir(installdir)
        tree.copy_tree(tree.descend(os.curdir()), installdir)
        tree.make_executable(path.join(installdir, "binl64"))
        tree.make_executable(path.join(installdir, "binl"))

        assert(os.isfile(path.join(installdir, "binl64", "wcl386")),
            "binl64/wcl386 missing after install")

        tree.mirror_to(installdir, "watcom")
    end)

    on_test("linux", function (package)
        local tree = import("toolchain_tree")
        local wcl = path.join(package:installdir(), "binl64", "wcl386")
        assert(os.isfile(wcl), "binl64/wcl386 missing after install")
        local text = tree.run_capture(wcl, {})
        assert(text:find("Watcom", 1, true) or text:find("usage", 1, true),
            "wcl386 did not report a banner: " .. text:sub(1, 60))
    end)

package_end()
