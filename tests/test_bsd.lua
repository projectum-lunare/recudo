-- Unit Tests: BSD Architecture Normalization, GNU Triples & Availability

import("detect.bsd", {rootdir = "modules"})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "normalize_arch maps standard aliases",
        func = function ()
            T.assert_equal(bsd.normalize_arch("amd64"), "x86_64")
            T.assert_equal(bsd.normalize_arch("aarch64"), "arm64")
            T.assert_equal(bsd.normalize_arch("powerpc"), "ppc")
            T.assert_equal(bsd.normalize_arch("powerpc64"), "ppc64")
            T.assert_equal(bsd.normalize_arch("powerpc64le"), "ppc64le")
            T.assert_equal(bsd.normalize_arch("powerpcspe"), "ppcspe")
            T.assert_equal(bsd.normalize_arch("macppc"), "ppc")
            T.assert_equal(bsd.normalize_arch("octeon"), "mips64")
            T.assert_equal(bsd.normalize_arch("landisk"), "sh4")
            T.assert_equal(bsd.normalize_arch("luna88k"), "m88k")
            T.assert_equal(bsd.normalize_arch("itanium"), "ia64")
        end
    })

    table.insert(tests, {
        name = "normalize_arch handles casing and whitespace",
        func = function ()
            T.assert_equal(bsd.normalize_arch("AMD64"), "x86_64")
            T.assert_equal(bsd.normalize_arch(" AArch64  "), "arm64")
            T.assert_equal(bsd.normalize_arch("x86_64"), "x86_64")
            T.assert_equal(bsd.normalize_arch("i386"), "i386")
        end
    })

    table.insert(tests, {
        name = "normalize_arch defaults nil to x86_64",
        func = function ()
            T.assert_equal(bsd.normalize_arch(nil), "x86_64")
        end
    })

    table.insert(tests, {
        name = "normalize_arch preserves and maps RISC-V variants",
        func = function ()
            T.assert_equal(bsd.normalize_arch("riscv32"), "riscv32")
            T.assert_equal(bsd.normalize_arch("riscv64"), "riscv64")
            T.assert_equal(bsd.normalize_arch("rv32"), "riscv32")
            T.assert_equal(bsd.normalize_arch("rv64"), "riscv64")
            -- NetBSD handles both riscv32 and riscv64
            T.assert_equal(bsd.normalize_arch("riscv32", "netbsd"), "riscv32")
            T.assert_equal(bsd.normalize_arch("riscv64", "netbsd"), "riscv64")
            T.assert_equal(bsd.normalize_arch("riscv", "netbsd"), "riscv64")
            -- FreeBSD and OpenBSD default riscv to riscv64
            T.assert_equal(bsd.normalize_arch("riscv", "freebsd"), "riscv64")
            T.assert_equal(bsd.normalize_arch("riscv", "openbsd"), "riscv64")
        end
    })

    table.insert(tests, {
        name = "get_triple_arch resolves correct GNU triples",
        func = function ()
            T.assert_equal(bsd.get_triple_arch("netbsd", "arm64"), "aarch64")
            T.assert_equal(bsd.get_triple_arch("netbsd", "i386"), "i486")
            T.assert_equal(bsd.get_triple_arch("netbsd", "riscv32"), "riscv32")
            T.assert_equal(bsd.get_triple_arch("netbsd", "riscv64"), "riscv64")
            T.assert_equal(bsd.get_triple_arch("freebsd", "arm64"), "aarch64")
            T.assert_equal(bsd.get_triple_arch("freebsd", "riscv64"), "riscv64")
            T.assert_equal(bsd.get_triple_arch("openbsd", "arm64"), "aarch64")
        end
    })

    table.insert(tests, {
        name = "get_prefixes produces valid toolchain prefixes",
        func = function ()
            local nbsd_r32 = bsd.get_prefixes("netbsd", "riscv32")
            T.assert_contains(nbsd_r32, "riscv32-netbsd-")
            T.assert_contains(nbsd_r32, "riscv32--netbsdelf-")

            local nbsd_r64 = bsd.get_prefixes("netbsd", "riscv64")
            T.assert_contains(nbsd_r64, "riscv64-netbsd-")
            T.assert_contains(nbsd_r64, "riscv64--netbsdelf-")

            local fbsd_arm64 = bsd.get_prefixes("freebsd", "arm64")
            T.assert_contains(fbsd_arm64, "aarch64-unknown-freebsd-")
            T.assert_contains(fbsd_arm64, "arm64-freebsd-")

            local dfly = bsd.get_prefixes("dragonflybsd", "x86_64")
            T.assert_contains(dfly, "x86_64-unknown-dragonfly-")
            T.assert_contains(dfly, "x86_64-dragonfly-")
        end
    })

    table.insert(tests, {
        name = "is_available returns false when cross-compiler is missing",
        func = function ()
            -- In an environment without FreeBSD cross toolchains installed:
            local avail = bsd.is_available("freebsd", "riscv64", {bindir = "/nonexistent/bin"})
            T.assert_false(avail, "riscv64 should not report available when no cross toolchain is installed")
        end
    })

    return tests
end
