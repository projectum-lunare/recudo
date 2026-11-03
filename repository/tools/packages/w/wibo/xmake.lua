-- Projectum Lunare Recudo - Toolchain Package: Wibo Win32 CLI Runner
-- Minimal, prefix-less Win32 PE loader that runs 32-bit Windows CE compilers
-- on Unix hosts. A dependency of the evc3 package on Linux and macOS.
--
-- Prebuilt artifacts only, one per host/arch (upstream publishes no arm64):
--   Linux x86_64 -> wibo-x86_64 (ELF x86-64, static)
--   Linux i386   -> wibo-i686   (ELF i386, static)
--   macOS        -> wibo-macos  (Mach-O x86_64; runs on Apple Silicon via
--                                Rosetta, which is required anyway -- the CE
--                                binaries it loads are x86)
--
-- Linux and macOS only:
--   * Windows runs the CE compilers natively (they are Win32 PE), so no
--     loader is needed there.
--   * BSD is out of scope by design. wibo drives Win32 32-bit code through
--     the LDT -- modify_ldt / set_thread_area / SYS_clone with CLONE_VM --
--     to build the flat segments that 32-bit Windows code expects. No BSD
--     kernel implements those (not even the FreeBSD linuxulator, which
--     covers a small, popularity-driven subset of the Linux ABI), and
--     OpenBSD removed its Linux emulation in 6.9. The single __FreeBSD__
--     ifdef upstream is a struct timeval detail in fileapi.cpp, not support.
--     A static binary also calls syscalls directly, so a libc-level
--     compatibility layer would never see them. FreeBSD users would need
--     Wine as the PE runner instead of wibo.
--
-- NOTE: xmake renames non-archive downloads to wibo-<version> in the package
-- cache dir and leaves the source dir empty.

package("wibo")
    set_homepage("https://github.com/decompals/wibo")
    set_description("Minimal, prefix-less Win32 PE binary runner for 32-bit Windows CLI compilers")

    -- prebuilt artifact per host/arch (upstream publishes no arm64 build):
    --   macOS            -> wibo-macos   (Mach-O x86_64, runs via Rosetta)
    --   Linux x86_64     -> wibo-x86_64  (ELF x86-64, static)
    --   Linux i386       -> wibo-i686    (ELF i386, static)
    if os.host() == "macosx" then
        add_urls("https://github.com/decompals/wibo/releases/download/$(version)/wibo-macos")
        add_versions("1.2.0", "2b3000ef6a7a490c24ccd71967735ae0005e218922e51806cca1b8d77fd3cf7c")
    elseif os.host() == "linux" and os.arch() == "i386" then
        add_urls("https://github.com/decompals/wibo/releases/download/$(version)/wibo-i686")
        add_versions("1.2.0", "2575d3b0a2f408b2c2b0850db56f1af5d005a138394a6774eba77b6708ecc304")
    elseif os.host() == "linux" and os.arch() == "x86_64" then
        add_urls("https://github.com/decompals/wibo/releases/download/$(version)/wibo-x86_64")
        add_versions("1.2.0", "13f86a2d618f0dbe67179d349625345eabf9b46450295cb4c904e49f6aff85af")
    else
        -- no upstream build for this host/arch (e.g. Linux arm64)
        raise("wibo has no prebuilt artifact for %s/%s", os.host(), os.arch())
    end

    on_load(function (package)
        package:addenv("PATH", "bin")
        package:addenv("WIBO_DIR", ".")
    end)

    on_install("linux", "macosx", function (package)
        local bindir = path.join(package:installdir(), "bin")
        os.mkdir(bindir)
        local installed = path.join(bindir, "wibo")

        -- the downloaded artifact is wibo-<version> (renamed by xmake) or the
        -- original asset name; anything else in the cache is stale
        local artifact = nil
        local accepted = {"wibo-" .. package:version(), "wibo-i686", "wibo-x86_64", "wibo-macos"}
        for _, f in ipairs(os.files(path.join(package:cachedir(), "*")) or {}) do
            for _, want in ipairs(accepted) do
                if path.filename(f) == want then
                    artifact = f
                end
            end
        end
        assert(artifact, "wibo artifact not found in the package cache")

        os.cp(artifact, installed)
        os.runv("chmod", {"0755", installed})

        -- contract mirror: the evc3 toolchain rule resolves
        -- WIBO_DIR -> ~/.local/opt/wibo/bin/wibo. Refreshed whenever the
        -- mirrored copy differs (a stale i686 mirror must not survive an
        -- x86_64 install, and vice versa).
        local home = os.getenv("HOME")
        local mirror_dir = home and path.join(home, ".local/opt/wibo/bin")
        if mirror_dir then
            local mirrored = path.join(mirror_dir, "wibo")
            local stale = true
            if os.isfile(mirrored) then
                local same = try {
                    function ()
                        return io.readfile(mirrored, {encoding = "binary"}) ==
                               io.readfile(installed, {encoding = "binary"})
                    end
                }
                stale = not same
            end
            if stale then
                os.mkdir(mirror_dir)
                os.cp(installed, mirrored, {force = true})
                tree.make_executable(mirror_dir)
            end
        end
    end)

    on_test("linux", "macosx", function (package)
        -- the loader prints nothing without a PE to run: verify structurally
        local tree = import("toolchain_tree")
        local wibo = path.join(package:installdir(), "bin", "wibo")
        assert(os.isfile(wibo), "wibo binary is missing")
        assert(os.isexec(wibo), "wibo binary is not executable")
        local kind = tree.run_capture("file", {"-b", wibo})
        assert(kind:find("ELF", 1, true) or kind:find("Mach-O", 1, true),
            "bin/wibo is not a native executable: " .. kind:sub(1, 80))
    end)

package_end()
