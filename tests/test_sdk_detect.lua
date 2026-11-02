-- Unit Tests: Centralized SDK and Watcom Detection

import("modules.detect.watcom", {rootdir = os.projectdir()})
import("modules.detect.sdk", {rootdir = os.projectdir()})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "watcom module exposes find_sdk and find_bindir functions",
        func = function ()
            T.assert_not_nil(watcom.find_sdk, "watcom.find_sdk should be defined")
            T.assert_not_nil(watcom.find_bindir, "watcom.find_bindir should be defined")
            T.assert_not_nil(watcom.get_env, "watcom.get_env should be defined")
            T.assert_not_nil(watcom.is_available, "watcom.is_available should be defined")
        end
    })

    table.insert(tests, {
        name = "watcom find_bindir rejects invalid or empty directories",
        func = function ()
            T.assert_nil(watcom.find_bindir(nil), "find_bindir should return nil for nil sdkdir")
            T.assert_nil(watcom.find_bindir("/nonexistent/watcom"), "find_bindir should return nil for nonexistent dir")
        end
    })

    table.insert(tests, {
        name = "watcom get_env generates complete environment variables",
        func = function ()
            local fake_sdk = path.join(os.tmpdir(), "recudo_mock_watcom")
            local fake_bin = path.join(fake_sdk, "binl64")
            local fake_h = path.join(fake_sdk, "h")
            local fake_dos_h = path.join(fake_sdk, "h/dos")
            os.mkdir(fake_bin)
            os.mkdir(fake_dos_h)

            local envs = watcom.get_env(fake_sdk, "dos32a")
            T.assert_equal(envs.WATCOM, fake_sdk)
            T.assert_equal(envs.EDPATH, path.join(fake_sdk, "eddat"))
            -- PATH must contain the bindir find_bindir resolves (binl64/binl/binnt64/binnt
            -- depending on host platform and pre-existing mock SDK leftovers in tmpdir)
            local bindir = watcom.find_bindir(fake_sdk)
            T.assert_not_nil(bindir, "find_bindir should resolve a bindir for the mock SDK")
            T.assert_true(envs.PATH:find(bindir, 1, true) ~= nil, "PATH should contain resolved bindir")
            T.assert_true(envs.INCLUDE:find(fake_h, 1, true) ~= nil, "INCLUDE should contain base header dir")

            os.rm(fake_sdk)
        end
    })

    table.insert(tests, {
        name = "sdk.exists verifies check_file presence",
        func = function ()
            local tmp = path.join(os.tmpdir(), "recudo_sdk_check_test")
            os.mkdir(tmp)

            -- Empty dir without check_file should be false when check_file is required
            local exists_empty = sdk.exists("recudo_sdk_test", nil, {
                fallbacks = tmp,
                check_file = "bin/compiler"
            })
            T.assert_false(exists_empty, "exists with check_file should fail if file is missing")

            -- Now create the file
            local bin_dir = path.join(tmp, "bin")
            os.mkdir(bin_dir)
            io.writefile(path.join(bin_dir, "compiler"), "mock compiler")

            local exists_with_file = sdk.exists("recudo_sdk_test", nil, {
                fallbacks = tmp,
                check_file = "bin/compiler"
            })
            T.assert_true(exists_with_file, "exists with check_file should succeed when file exists")

            os.rm(tmp)
        end
    })

    table.insert(tests, {
        name = "recudo plugin is_sdk_available checks host and architecture compatibility",
        func = function ()
            local recudo_main = import("plugins.recudo.main", {rootdir = os.projectdir()})

            -- Mismatched arch on host should never be host-compatible
            local host_plat = os.host()
            T.assert_false(recudo_main.is_host_compatible(host_plat, "riscv64"),
                "Host platform should not be compatible with riscv64 unless host is riscv64")

            -- Matching arch should be compatible
            T.assert_true(recudo_main.is_host_compatible(host_plat, os.arch()),
                "Host platform should be compatible with its own native arch")

            -- POSIX target with riscv64 should not be available without cross-compiler
            local t_posix = {id = "posix", plat = host_plat, arch = os.arch()}
            T.assert_false(recudo_main.is_sdk_available(t_posix, "riscv64"),
                "POSIX target with riscv64 should not report available on non-riscv64 host")
        end
    })

    table.insert(tests, {
        name = "is_sdk_available rejects empty directories without required binaries",
        func = function ()
            local recudo_main = import("plugins.recudo.main", {rootdir = os.projectdir()})
            local tmp_empty = path.join(os.tmpdir(), "recudo_empty_sdk_test")
            os.mkdir(tmp_empty)

            -- Mock targets pointing to the empty directory via custom env variable
            local t_watcom = {
                id = "dos",
                plat = "dos",
                arch = "i386",
                sdk_name = "watcom",
                sdk_env = "RECUDO_MOCK_EMPTY_WATCOM"
            }
            local t_amiga = {
                id = "amiga",
                plat = "amiga",
                arch = "m68k",
                sdk_name = "amigaos-sdk",
                sdk_env = "RECUDO_MOCK_EMPTY_AMIGA",
                check_file = "bin/m68k-amigaos-gcc"
            }
            local t_wince = {
                id = "wince",
                plat = "wince",
                arch = "arm",
                sdk_name = "evc3",
                sdk_env = "RECUDO_MOCK_EMPTY_EVC3"
            }

            os.setenv("RECUDO_MOCK_EMPTY_WATCOM", tmp_empty)
            os.setenv("RECUDO_MOCK_EMPTY_AMIGA", tmp_empty)
            os.setenv("RECUDO_MOCK_EMPTY_EVC3", tmp_empty)

            T.assert_false(recudo_main.is_sdk_available(t_watcom),
                "Watcom target must not report available when directory has no owcc")
            T.assert_false(recudo_main.is_sdk_available(t_amiga),
                "Amiga target must not report available when gcc binary is missing")
            T.assert_false(recudo_main.is_sdk_available(t_wince),
                "WinCE target must not report available when clarm.exe/link.exe are missing")

            os.setenv("RECUDO_MOCK_EMPTY_WATCOM", nil)
            os.setenv("RECUDO_MOCK_EMPTY_AMIGA", nil)
            os.setenv("RECUDO_MOCK_EMPTY_EVC3", nil)
            os.rm(tmp_empty)
        end
    })

    table.insert(tests, {
        name = "get_sdk_path provides clear descriptive diagnostics for missing tools",
        func = function ()
            local recudo_main = import("plugins.recudo.main", {rootdir = os.projectdir()})

            -- Check POSIX host description
            local t_posix = {id = "posix", plat = os.host(), arch = os.arch()}
            local posix_desc = recudo_main.get_sdk_path(t_posix, os.arch())
            T.assert_equal(posix_desc, "Host Native Development Tools")

            -- Check BSD target when cross compiler is missing
            local t_freebsd = {id = "freebsd", plat = "freebsd", arch = "x86_64", sdk_env = "FREEBSD_SDK"}
            local bsd_desc = recudo_main.get_sdk_path(t_freebsd, "riscv64")
            T.assert_true(bsd_desc:find("missing") ~= nil, "BSD missing toolchain should be labeled as missing")

            -- Check Watcom target with empty directory
            local tmp_empty = path.join(os.tmpdir(), "recudo_empty_watcom_diag")
            os.mkdir(tmp_empty)
            local t_watcom = {id = "dos", plat = "dos", arch = "i386", sdk_env = "RECUDO_MOCK_DIAG_WATCOM"}
            os.setenv("RECUDO_MOCK_DIAG_WATCOM", tmp_empty)

            local watcom_desc = recudo_main.get_sdk_path(t_watcom, "i386")
            T.assert_true(watcom_desc:find("owcc missing") ~= nil, "Watcom empty directory should mention owcc missing")

            os.setenv("RECUDO_MOCK_DIAG_WATCOM", nil)
            os.rm(tmp_empty)
        end
    })

    return tests
end
