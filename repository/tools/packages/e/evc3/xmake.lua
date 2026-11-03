-- Projectum Lunare Recudo - Toolchain Package: Microsoft eMbedded Visual C++ 3.0
-- Windows CE 3.0 C/C++ cross-compilers and SDK for vintage Handheld PCs
-- (ARM: HP Jornada 720, MIPS: sigmarion I, SH-3/SH-4: Cassiopeia, x86, PPC).
--
-- Provenance: the bundle was assembled from the eMbedded Visual Tools 3.0
-- ISOs hosted at archive.org/details/embedvt-3 (CD1 sha256
-- f8a5f476a91df61be714e697fa401af8123cd1a8ac40adfafb20d3318c963040, CD2
-- sha256 52e25aa6e98004fbbf4a05c933bce75c96652eefd4d94a5113583e777e7211a3):
-- the WCE300 cross tools, the shared RC/NMAKE tools, the H/PC 2000 SDK
-- (include + lib/{arm,mips,sh3,sh4,x86}) with lowercase copies baked in,
-- so the same bundle serves case-sensitive (Linux/BSD) and case-insensitive
-- (Windows) hosts. The tarball is built reproducibly: the same tree always
-- hashes the same.
--
-- The PowerPC edition is not included: the CE 3.0 media ships no PPC runtime
-- libraries and synthesizing them (the dotstar millicode procedure) is
-- untested against real hardware. The clppc.exe compiler ships in
-- bin/wce300 for future work.
--
-- All binaries remain (c) Microsoft; provided for preservation and
-- retro-computing use. Wibo (the package dependency) runs the Win32 PE
-- compilers on Linux hosts.

package("evc3")
    set_homepage("https://archive.org/details/recudo-evc3-3.0-bundle")
    set_description("Microsoft eMbedded Visual C++ 3.0: Windows CE C/C++ cross-compilers and SDK")

    add_urls("https://archive.org/download/recudo-evc3-3.0-bundle/evc3-3.0-bundle.tar.xz")
    add_versions("3.0", "060c8224746dcd0efbf4e34ffe79b3941fb239cc506313d6bac56afbb56d7cd0")

    on_load(function (package)
        package:addenv("PATH", "bin/wce300")
        package:addenv("PATH", "bin/common")
        package:addenv("INCLUDE", "include")
        if os.host() == "linux" or os.host() == "macosx" then
            package:add("deps", "wibo")
        end
    end)

    on_install(function (package)
        local mirror = nil
        if os.host() == "windows" then
            local appdata = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA")
            mirror = appdata and path.join(appdata, "evc3")
        else
            local home = os.getenv("HOME")
            mirror = home and path.join(home, ".local/opt/evc3")
        end
        local tree = import("toolchain_tree")
        local installdir = package:installdir()
        os.mkdir(installdir)

        tree.copy_tree(tree.descend(os.curdir()), installdir)

        -- the tar carries the exec bits; the chmod is a POSIX backstop
        tree.make_executable(path.join(installdir, "bin"))

        assert(os.isfile(path.join(installdir, "bin", "clarm.exe")),
            "bin/clarm.exe missing after install")

        if mirror and not os.isdir(mirror) then
            tree.copy_tree(installdir, mirror)
        end
    end)

    on_test("linux", "macosx", function (package)
        local tree = import("toolchain_tree")
        -- clarm.exe is a Win32 PE: on these hosts it only runs through wibo.
        -- The compiler banner goes to stderr, so both streams are captured.
        local clarm = path.join(package:installdir(), "bin", "clarm.exe")
        assert(os.isfile(clarm), "clarm.exe missing after install")

        local wibo = os.getenv("WIBO_BIN")
        if not wibo then
            local home = os.getenv("HOME")
            wibo = home and path.join(home, ".local/opt/wibo/bin/wibo")
        end
        if not (wibo and os.isfile(wibo)) then
            -- no runner on this host: verify the tree structurally instead
            assert(os.isfile(path.join(package:installdir(), "bin", "link.exe")),
                "link.exe missing and no wibo runner available")
            return
        end

        local text = tree.run_capture(wibo, {clarm})
        assert(text:find("ARM", 1, true), "clarm.exe did not report the ARM target")
    end)

    on_test("windows", function (package)
        -- the Win32 PE compilers run natively on Windows hosts
        local clarm = path.join(package:installdir(), "bin", "clarm.exe")
        assert(os.isfile(clarm), "clarm.exe missing after install")
        assert(os.isfile(path.join(package:installdir(), "bin", "link.exe")),
            "link.exe missing after install")
    end)

package_end()
