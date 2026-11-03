-- Projectum Lunare Recudo - Toolchain Package: Atari ST / FreeMiNT (m68k)
-- The modern m68k-atari-mintelf cross toolchain, assembled from six packages
-- of Vincent Riviere's Debian repository (repo root below). No bundle is
-- re-hosted: every artifact comes straight from the upstream repo, pinned by
-- the SHA256 published in its Packages index.
--
--   binutils  2.42-mintelf-20240218   f7b2c0c7...
--   mintbin   0.3-Git-20230913        d96c1389...
--   gcc       13.3.0-mintelf-20240529 e7369041492...
--   mintlib   0.60.1-Git-20240114     99097852...
--   fdlibm    5.3-Git-20230207        130ce426...
--   gemlib    0.44.0-Git-20230901     72621d09...
--
-- This supersedes the legacy m68k-atari-mint toolchain (GCC 4.6.4, 2011),
-- whose GDB cannot debug binaries built by GCC 4.x and which predates the
-- PRG/ELF format. See atarist-mint for the classic one.
--
-- A .deb is an ar archive: ar x -> data.tar.(zst|gz|xz) -> the usr/ level is
-- merged into the toolchain tree.
--
-- Repo: http://vincent.riviere.free.fr/apt/
--   Types: deb
--   URIs: http://vincent.riviere.free.fr/apt/
--   Suites: trixie  (bookworm also published)
--   Components: contrib
-- Only the binary-amd64/all packages are needed; no apt integration.

local DEB_ROOT = "http://vincent.riviere.free.fr/apt/dists/trixie/contrib/binary-amd64/"

package("atarist-mintelf")
    set_homepage("http://vincent.riviere.free.fr/soft/m68k-atari-mintelf/")
    set_description("m68k-atari-mintelf GCC 13.3.0, binutils 2.42 and MiNTLib for Atari ST / TT / Falcon")

    -- xmake fetches a single artifact per package (the urls above are
    -- mirrors, not separate files), so the other five .debs are downloaded
    -- from the same repo inside on_install and pinned by the same hashes.
    add_urls(DEB_ROOT .. "binutils-m68k-atari-mintelf_2.42-mintelf-20240218-1_amd64.deb")
    add_versions("13.3.0", "f7b2c0c7092b82d26591f89255e4b9ed605525d566ff5688369301ba89fb97a5")

    local EXTRA_DEBS = {
        {"mintbin-m68k-atari-mintelf_0.3-Git-20230913-1_amd64.deb",
         "d96c1389c4bf1b3b000217d702ee8d1fb7e3916cf485b6949b0382f43b9077de"},
        {"gcc-m68k-atari-mintelf_13.3.0-mintelf-20240529-1_amd64.deb",
         "e7369041492b227e1452bf1229a3f07ca74f974c1655d6ef97ddd4bd9da0aafa"},
        {"mintlib-m68k-atari-mintelf_0.60.1-Git-20240114-1_all.deb",
         "99097852c70b915692271a225ef5dc2b720754bc11e922baa24a5070e279025b"},
        {"fdlibm-m68k-atari-mintelf_5.3-Git-20230207-3_all.deb",
         "130ce426ca0dbdcea44fceb7e7935c57c3bcf843807d765b21200501afa87816"},
        {"gemlib-m68k-atari-mintelf_0.44.0-Git-20230901-1_all.deb",
         "72621d095c3c97c2ac8b019e26776c4abe3305394c82df9e601ebb4659c98778"},
    }

    on_load(function (package)
        package:addenv("PATH", "bin")
        package:addenv("ATARIST_MINTELF", ".")
    end)

    on_install("linux", function (package)
        local tree = import("toolchain_tree")

        local installdir = package:installdir()
        os.mkdir(installdir)

        -- fetch the remaining five artifacts (the package url covers binutils)
        local fetchdir = path.join(package:cachedir(), "debs")
        os.mkdir(fetchdir)
        for _, entry in ipairs(EXTRA_DEBS) do
            tree.fetch_pinned(DEB_ROOT .. entry[1], entry[2], path.join(fetchdir, entry[1]))
        end

        -- every .deb is an ar archive wrapping data.tar.*; merge all six
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
        assert(count >= 6, ("expected 6 .deb packages, unpacked %d"):format(count))

        tree.make_executable(path.join(installdir, "bin"))
        assert(os.isfile(path.join(installdir, "bin", "m68k-atari-mintelf-gcc")),
            "m68k-atari-mintelf-gcc missing after install")

        tree.mirror_to(installdir, "atarist-mintelf")
    end)

    on_test("linux", function (package)
        local tree = import("toolchain_tree")
        local gcc = path.join(package:installdir(), "bin", "m68k-atari-mintelf-gcc")
        assert(os.isfile(gcc), "m68k-atari-mintelf-gcc missing after install")
        local text = tree.run_capture(gcc, {"--version"})
        assert(text:find("13.3.0", 1, true), "unexpected version: " .. text:sub(1, 60))
    end)

package_end()
