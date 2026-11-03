-- Projectum Lunare Recudo - Toolchain Package: vbcc
-- Volker Barthelmann's portable ISO C compiler, with vasm and vlink.
-- One multi-target distribution covers every backend it ships:
--   m68k    AmigaOS, Atari TOS/MiNT, Atari Jaguar, Linux
--   ppc     AmigaOS, MorphOS, WarpOS, PowerUp, Linux, NetBSD
--   6502    C64, C128, C16, VIC-20, PET, Atari 8bit, BBC, NES, MEGA65,
--           Commander X16, Apple I/II, Oric, SNES (65816), simulator
--   z80/i386/c16x/qnice/alpha/vidcore/6809/6800
--   (targets/ carries the matching libc for each one)
--
-- vbcc is an alternative to the GCC cross toolchains for the same platforms,
-- and the only option for most of the 8-bit ones. It typically produces much
-- smaller binaries than GCC because its libc is minimal: a bare
-- `int main(void){return 0;}` is ~1 KB for AmigaOS and 252 bytes for the C64,
-- against ~130 KB with a GCC toolchain.
--
-- vbcc finds its target configurations through the VBCC environment variable,
-- which must point at the installation root (the directory holding config/).
-- Without it the driver aborts with "No config file!".

package("vbcc")
    set_homepage("http://www.compilers.de/vbcc.html")
    set_description("Portable ISO C compiler (vbcc) with vasm/vlink for m68k, PPC, 6502, Z80 and more")

    add_urls("http://www.ibaug.de/vbcc/vbcc_linux_x64.tar.gz")
    add_versions("0.9", "8df915db78e2fc8ee844430fb3c62d2b44dde662072054fee47c344cbd444fcc")

    on_load(function (package)
        package:addenv("PATH", "bin")
        -- the driver reads its target configs from $VBCC/config
        package:addenv("VBCC", ".")
    end)

    on_install("linux", function (package)
        local tree = import("toolchain_tree")

        local installdir = package:installdir()
        os.mkdir(installdir)
        tree.copy_tree(tree.descend(os.curdir()), installdir)
        tree.make_executable(path.join(installdir, "bin"))

        assert(os.isfile(path.join(installdir, "bin", "vbccm68k")), "vbccm68k missing after install")
        assert(os.isdir(path.join(installdir, "config")), "target configs missing after install")

        tree.mirror_to(installdir, "vbcc")
    end)

    on_test("linux", function (package)
        -- the real smoke test: drive the m68k backend through the vc frontend
        -- with VBCC pointing at the config dir, and check the object produced
        local tree = import("toolchain_tree")
        local installdir = package:installdir()
        local bindir = path.join(installdir, "bin")
        assert(os.isfile(path.join(bindir, "vc")), "vc frontend missing after install")

        local tmpdir = path.join(package:cachedir(), "smoketest")
        os.tryrm(tmpdir)
        os.mkdir(tmpdir)
        local src = path.join(tmpdir, "probe.c")
        io.writefile(src, "int main(void){return 0;}\n")

        local envs = {VBCC = installdir, PATH = bindir .. path.envsep() .. (os.getenv("PATH") or "")}
        local obj = path.join(tmpdir, "probe.o")
        local ok, err = try {
            function ()
                os.runv(path.join(bindir, "vc"), {"+aos68k", "-c", src, "-o", obj},
                    {envs = envs, curdir = tmpdir})
                return true
            end,
            catch {
                function (e)
                    return false, tostring(e)
                end
            }
        }
        assert(ok, "vc +aos68k failed: " .. tostring(err))
        assert(os.isfile(obj), "vc +aos68k produced no object file")
    end)

package_end()
