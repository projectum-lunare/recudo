-- Projectum Lunare Recudo - Toolchain Package: KolibriOS SDK (kos32-gcc)
-- The KolibriOS GCC cross-compiler and SDK from ftp.kolibrios.org. xmake
-- extracts the toolchain archive itself (it knows .7z) and leaves the SDK
-- archive in the cache, so the install copies one and unpacks the other.

package("kolibrios-sdk")
    set_homepage("https://kolibrios.org")
    set_description("KolibriOS GCC cross-compiler (kos32-gcc) and SDK for KolibriOS")

    add_urls("http://ftp.kolibrios.org/users/Serge/new/Toolchain/x86_64-linux-kos32-$(version).7z")
    add_versions("5.4.0", "7ded2eafac38362fd51bcf15b721657edf57e3f9789bf3adb1387094128c92c6")

    local SDK_URL = "http://ftp.kolibrios.org/users/Serge/new/Toolchain/sdk-28-10-16.7z"
    local SDK_SHA = "571efc16eea54115fbce9e078325e1bc9e416ca4976e86ec9e66d3539a213f8d"

    on_load(function (package)
        package:addenv("PATH", "bin")
        package:addenv("KOLIBRIOS_SDK", ".")
    end)

    on_install("linux", function (package)
        local tree = import("toolchain_tree")
        local find_tool = import("lib.detect.find_tool")

        local installdir = package:installdir()
        os.mkdir(installdir)

        -- the toolchain archive is already extracted into the source dir
        tree.merge_into(os.curdir(), installdir)

        -- the SDK archive: fetch, verify and unpack
        local sdk = tree.fetch_pinned(SDK_URL, SDK_SHA,
            path.join(package:cachedir(), "sdk-28-10-16.7z"))
        local sevenzip = find_tool("7z") or find_tool("7za")
        assert(sevenzip, "extracting the KolibriOS SDK requires 7-Zip (p7zip)")
        os.runv(sevenzip.program, {"x", "-y", "-o" .. path.join(installdir, "sdk"), sdk})

        tree.make_executable(path.join(installdir, "bin"))
        assert(os.isfile(path.join(installdir, "bin", "kos32-gcc")),
            "kos32-gcc missing after install")

        tree.mirror_to(installdir, "kolibrios-sdk")
    end)

    on_test("linux", function (package)
        local tree = import("toolchain_tree")
        local gcc = path.join(package:installdir(), "bin", "kos32-gcc")
        assert(os.isfile(gcc), "kos32-gcc missing after install")
        local text = tree.run_capture(gcc, {"--version"})
        assert(text:find("gcc", 1, true) or text:find("GCC", 1, true),
            "kos32-gcc did not report a version")
    end)

package_end()
