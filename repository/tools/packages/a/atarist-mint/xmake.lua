-- Projectum Lunare Recudo - Toolchain Package: Atari ST / FreeMiNT (m68k), classic
-- The legacy m68k-atari-mint toolchain: GCC 4.6.4, binutils 2.30, MiNTLib
-- 0.60.1. Kept alongside atarist-mintelf because the two are genuinely
-- different toolchains, not two versions of one:
--
--   atarist-mint     a.out-zero-big objects, classic TOS executable with the
--                    228-byte loader trick, leading-underscore symbol
--                    convention, -Wl,--traditional-format for MonST2 and
--                    other classic Atari debuggers.
--   atarist-mintelf  ELF objects, PRG/ELF executable, no underscore prefix,
--                    GDB support, modern C++.
--
-- Pick this one for legacy source trees written against the old convention,
-- or when a classic Atari debugger must read the symbols. Otherwise prefer
-- atarist-mintelf.
--
-- Provenance: assembled from three packages of Vincent Riviere's m68k-atari-mint
-- PPA, each verified against the SHA256 published in the PPA Packages index:
--   binutils-m68k-atari-mint  2.30-mint-20180703   8c32facf...
--   gcc-m68k-atari-mint       4.6.4-mint-20251014  0432aca2...
--   mintlib-m68k-atari-mint   0.60.1.Git-20220821  731eea32...

local DEB_ROOT = "http://vincent.riviere.free.fr/apt/dists/trixie/contrib/binary-amd64/"

package("atarist-mint")
    set_homepage("http://vincent.riviere.free.fr/soft/m68k-atari-mint/")
    set_description("m68k-atari-mint GCC 4.6.4, binutils 2.30 and MiNTLib (classic a.out/TOS toolchain)")

    -- Same Debian repo as atarist-mintelf, three artifacts instead of six.
    -- xmake fetches one artifact per package, so the other two are downloaded
    -- inside on_install and pinned by the hashes published in the repo index.
    add_urls(DEB_ROOT .. "binutils-m68k-atari-mint_2.30-mint-20180703-2_amd64.deb")
    add_versions("4.6.4", "8574686f8c48c0174c3f24c381f751f6c0a57b93544498f85e2f796b8c822967")

    local EXTRA_DEBS = {
        {"gcc-m68k-atari-mint_4.6.4-mint-20200504-6_amd64.deb",
         "02171d0c4db8b07d86d69488e874791da739db3b80d05ddf2fbe2f7b7564ea3e"},
        {"mintlib-m68k-atari-mint_0.60.1.Git-20220821-1_all.deb",
         "94508cafe7724dcb0d952d0e5d9204008317389290306c5fbecc4e6ff7b689d3"},
    }

    on_load(function (package)
        package:addenv("PATH", "bin")
        package:addenv("ATARIST_SDK", ".")
    end)

    on_install("linux", function (package)
        local tree = import("toolchain_tree")

        local installdir = package:installdir()
        os.mkdir(installdir)

        -- fetch the two extra artifacts (the package url covers binutils)
        local fetchdir = path.join(package:cachedir(), "debs")
        os.mkdir(fetchdir)
        for _, entry in ipairs(EXTRA_DEBS) do
            tree.fetch_pinned(DEB_ROOT .. entry[1], entry[2], path.join(fetchdir, entry[1]))
        end

        local debs = {}
        for _, dir in ipairs({os.curdir(), package:cachedir(), fetchdir}) do
            for _, f in ipairs(os.files(path.join(dir, "*.deb")) or {}) do
                debs[f] = true
            end
        end
        local count = 0
        for deb in pairs(debs) do
            tree.install_deb(deb, installdir,
                path.join(package:cachedir(), "ar", path.basename(deb)))
            count = count + 1
        end
        assert(count >= 3, ("expected 3 .deb packages, unpacked %d"):format(count))

        tree.make_executable(path.join(installdir, "bin"))
        assert(os.isfile(path.join(installdir, "bin", "m68k-atari-mint-gcc")),
            "m68k-atari-mint-gcc missing after install")

        tree.mirror_to(installdir, "atarist-mint")
    end)

    on_test("linux", function (package)
        local tree = import("toolchain_tree")
        local gcc = path.join(package:installdir(), "bin", "m68k-atari-mint-gcc")
        assert(os.isfile(gcc), "m68k-atari-mint-gcc missing after install")
        local text = tree.run_capture(gcc, {"--version"})
        assert(text:find("4.6.4", 1, true), "unexpected version: " .. text:sub(1, 60))
    end)

package_end()
