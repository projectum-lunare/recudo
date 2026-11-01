-- Unit Tests: Vintage Compiler Rules (Watcom & eVC3)

import("modules.sdk", {rootdir = os.projectdir()})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "watcom rule supports C and C++ extensions",
        func = function ()
            local content = io.readfile("rules/toolchain/watcom/xmake.lua")
            T.assert_not_nil(content)
            T.assert_true(content:find('%.cpp') ~= nil, "Watcom rule should support .cpp")
            T.assert_true(content:find('%.cc') ~= nil, "Watcom rule should support .cc")
            T.assert_true(content:find('%.cxx') ~= nil, "Watcom rule should support .cxx")
        end
    })

    table.insert(tests, {
        name = "watcom rule does not pass separated -x and c/c++ arguments",
        func = function ()
            local content = io.readfile("rules/toolchain/watcom/xmake.lua")
            -- Ensure "-x" is never pushed as an independent argv element
            T.assert_nil(content:match('table%.insert%(argv,%s*["\']%-x["\']%)'),
                "Watcom rule must NOT pass separated -x argument; owcc requires attached -xc / -xc++ or no -x for C")
            -- Ensure -xc++ is used for C++
            T.assert_not_nil(content:match('table%.insert%(argv,%s*["\']%-xc%+%+["\']%)'),
                "Watcom rule must pass attached -xc++ for C++")
        end
    })

    table.insert(tests, {
        name = "watcom real compiler test: compiles .c and .cpp without c.c error",
        func = function ()
            import("modules.detect.watcom", {rootdir = os.projectdir()})
            local sdkdir = watcom.find_sdk("WATCOM")
            if not sdkdir or not os.isdir(sdkdir) then
                return
            end

            local bindir = watcom.find_bindir(sdkdir)
            if not bindir then
                return
            end

            local owcc = path.join(bindir, "owcc")
            if not os.isexec(owcc) then
                return
            end

            local tmpdir = path.join(os.tmpdir(), "forge_watcom_test")
            os.mkdir(tmpdir)

            local c_file = path.join(tmpdir, "test.c")
            local cpp_file = path.join(tmpdir, "test.cpp")
            local h_file = path.join(tmpdir, "test.h")
            local c_obj = path.join(tmpdir, "test_c.o")
            local cpp_obj = path.join(tmpdir, "test_cpp.o")

            io.writefile(h_file, "#define VALUE 42\n")
            io.writefile(c_file, '#include "test.h"\nint get_val(void) { return VALUE; }\n')
            io.writefile(cpp_file, '#include "test.h"\nclass C { public: int v; }; int get_cpp(void) { C c; c.v = VALUE; return c.v; }\n')

            local envs = watcom.get_env(sdkdir, "dos32a")

            -- 1. Compile C file using watcom rule flags (-std=ow)
            local argv_c = {
                "-b", "dos32a",
                "-std=ow",
                "-O2",
                "-I" .. tmpdir,
                "-c",
                "-o", c_obj,
                c_file
            }
            local ok_c = try { function () os.execv(owcc, argv_c, {envs = envs, curdir = tmpdir}) return true end }
            T.assert_true(ok_c == true, "C compilation with owcc failed")
            T.assert_true(os.isfile(c_obj), "C object file not generated")

            -- 2. Compile C++ file using watcom rule flags (-xc++)
            local argv_cpp = {
                "-b", "dos32a",
                "-xc++",
                "-O2",
                "-I" .. tmpdir,
                "-c",
                "-o", cpp_obj,
                cpp_file
            }
            local ok_cpp = try { function () os.execv(owcc, argv_cpp, {envs = envs, curdir = tmpdir}) return true end }
            T.assert_true(ok_cpp == true, "C++ compilation with owcc -xc++ failed")
            T.assert_true(os.isfile(cpp_obj), "C++ object file not generated")

            -- Cleanup
            os.rm(tmpdir)
        end
    })

    table.insert(tests, {
        name = "evc3 rule supports C and C++ extensions",
        func = function ()
            local content = io.readfile("rules/toolchain/evc3/xmake.lua")
            T.assert_not_nil(content)
            T.assert_true(content:find('%.cpp') ~= nil, "eVC3 rule should support .cpp")
            T.assert_true(content:find('%.cc') ~= nil, "eVC3 rule should support .cc")
            T.assert_true(content:find('%.cxx') ~= nil, "eVC3 rule should support .cxx")
        end
    })

    table.insert(tests, {
        name = "watcom rule dynamically maps optimization, symbols and warnings",
        func = function ()
            local content = io.readfile("rules/toolchain/watcom/xmake.lua")
            T.assert_true(content:find('-O0') ~= nil, "Watcom should map -O0 for none/debug")
            T.assert_true(content:find('-O2') ~= nil, "Watcom should map -O2")
            T.assert_true(content:find('-Os') ~= nil, "Watcom should map -Os")
            T.assert_true(content:find('-g2') ~= nil, "Watcom should map -g2")
            T.assert_true(content:find('cxflags') ~= nil, "Watcom should propagate target cxflags")
        end
    })

    table.insert(tests, {
        name = "evc3 rule dynamically maps optimization, symbols and warnings",
        func = function ()
            local content = io.readfile("rules/toolchain/evc3/xmake.lua")
            T.assert_true(content:find('/Od') ~= nil, "eVC3 should map /Od for none/debug")
            T.assert_true(content:find('/O1') ~= nil, "eVC3 should map /O1 for space")
            T.assert_true(content:find('/O2') ~= nil, "eVC3 should map /O2 for speed")
            T.assert_true(content:find('/Z7') ~= nil, "eVC3 should map /Z7 for symbols")
            T.assert_true(content:find('/TP') ~= nil, "eVC3 should use /TP for C++")
            T.assert_true(content:find('cxflags') ~= nil, "eVC3 should propagate target cxflags")
        end
    })

    table.insert(tests, {
        name = "watcom rule tracks header dependencies with -MMD -MF and parse_deps",
        func = function ()
            local content = io.readfile("rules/toolchain/watcom/xmake.lua")
            T.assert_true(content:find('-MMD') ~= nil, "Watcom rule should emit -MMD")
            T.assert_true(content:find('-MF') ~= nil, "Watcom rule should emit -MF")
            T.assert_true(content:find('parse_deps') ~= nil, "Watcom rule should parse depfiles")
            T.assert_true(content:find('batchcmds:add_depfiles') ~= nil, "Watcom rule should register depfiles")
        end
    })

    table.insert(tests, {
        name = "evc3 rule tracks header dependencies recursively",
        func = function ()
            local content = io.readfile("rules/toolchain/evc3/xmake.lua")
            T.assert_true(content:find('scan_evc3_includes') ~= nil, "eVC3 rule should define recursive include scanner")
            T.assert_true(content:find('batchcmds:add_depfiles') ~= nil, "eVC3 rule should register found headers")
        end
    })

    table.insert(tests, {
        name = "evc3 rule links executables via link.exe and archives via lib.exe without host ar",
        func = function ()
            local content = io.readfile("rules/toolchain/evc3/xmake.lua")
            T.assert_true(content:find('link%.exe') ~= nil, "eVC3 rule must invoke link.exe for binaries")
            T.assert_true(content:find('/subsystem:windowsce') ~= nil, "eVC3 rule must specify /subsystem:windowsce")
            T.assert_true(content:find('/MACHINE:') ~= nil, "eVC3 rule must pass /MACHINE: architecture")
            T.assert_true(content:find('WinMainCRTStartup') ~= nil, "eVC3 rule should provide WinMainCRTStartup entry point fallback")
            T.assert_true(content:find('coredll%.lib') ~= nil, "eVC3 rule must include coredll.lib")
            T.assert_true(content:find('lib%.exe') ~= nil, "eVC3 rule must invoke lib.exe for static libraries")
            T.assert_nil(content:match('batchcmds:vrunv%(["\']ar["\']'), "eVC3 rule must not call host ar")
        end
    })

    table.insert(tests, {
        name = "rules safely resolve and deduplicate object files",
        func = function ()
            local watcom_content = io.readfile("rules/toolchain/watcom/xmake.lua")
            local evc3_content = io.readfile("rules/toolchain/evc3/xmake.lua")

            T.assert_true(watcom_content:find('modules%.objectfiles') ~= nil, "Watcom rule should use the shared object file list")
            T.assert_true(watcom_content:find('table%.contains%(current_objs,%s*objfile%)') ~= nil, "Watcom rule should guard against duplicate objectfiles")

            T.assert_true(evc3_content:find('modules%.objectfiles') ~= nil, "eVC3 rule should use the shared object file list")
            T.assert_true(evc3_content:find('table%.contains%(current_objs,%s*objfile%)') ~= nil, "eVC3 rule should guard against duplicate objectfiles")
        end
    })

    table.insert(tests, {
        name = "evc3 end-to-end dry-run generates link.exe with wince subsystem and arm machine",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_evc3_bin")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/main.c"), "int main() { return 0; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("app")
    set_kind("binary")
    add_rules("forge.evc3", {override = true})
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "wince", "-a", "arm"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("clarm%.exe") ~= nil, "dry-run must invoke clarm.exe for compiling")
            T.assert_true(out:find("link%.exe") ~= nil, "dry-run must invoke link.exe for linking")
            T.assert_true(out:find("/subsystem:windowsce,3%.00") ~= nil, "dry-run must pass /subsystem:windowsce,3.00")
            T.assert_true(out:find("/MACHINE:ARM") ~= nil, "dry-run must pass /MACHINE:ARM")
            T.assert_true(out:find("/entry:WinMainCRTStartup") ~= nil, "dry-run must pass /entry:WinMainCRTStartup")
            T.assert_true(out:find("coredll%.lib") ~= nil, "dry-run must include coredll.lib")
            T.assert_nil(out:match("%s+ar%s+cr"), "dry-run must not invoke host ar")
        end
    })

    table.insert(tests, {
        name = "evc3 end-to-end dry-run archives static libraries with lib.exe",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_evc3_static")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/lib.c"), "int foo() { return 1; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("mylib")
    set_kind("static")
    add_rules("forge.evc3", {override = true})
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "wince", "-a", "arm"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("lib%.exe") ~= nil, "dry-run must invoke lib.exe for static library")
            T.assert_true(out:find("/out:") ~= nil, "dry-run must pass /out: to lib.exe")
            T.assert_nil(out:match("%s+ar%s+cr"), "dry-run must not invoke host ar")
        end
    })

    table.insert(tests, {
        name = "evc3 end-to-end dry-run honors custom entry point",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_evc3_entry")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/main.c"), "int main() { return 0; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("cli_app")
    set_kind("binary")
    add_rules("forge.evc3", {override = true})
    set_values("evc3.entry", "mainACRTStartup")
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "wince", "-a", "arm"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("/entry:mainACRTStartup") ~= nil, "dry-run must pass /entry:mainACRTStartup")
            T.assert_nil(out:find("WinMainCRTStartup"), "dry-run must not pass WinMainCRTStartup when custom entry is set")
        end
    })

    table.insert(tests, {
        name = "watcom end-to-end dry-run builds binary, static lib and dll with owcc and wlib",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_watcom_e2e")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/main.c"), "int main() { return 0; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("dos_app")
    set_kind("binary")
    add_rules("forge.watcom", {override = true})
    add_files("src/*.c")
target("dos_lib")
    set_kind("static")
    add_rules("forge.watcom", {override = true})
    add_files("src/*.c")
target("dos_dll")
    set_kind("shared")
    add_rules("forge.watcom", {override = true})
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "dos", "-a", "i386"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("owcc.*%-b%s+dos32a.*%-std=ow") ~= nil, "dry-run must invoke owcc with -b dos32a")
            T.assert_true(out:find("wlib.*%-q%s+%-b%s+%-c%s+%-n") ~= nil, "dry-run must invoke wlib for static lib")
            T.assert_true(out:find("owcc.*%-bd%s+%-b%s+dos32a") ~= nil, "dry-run must invoke owcc -bd for shared DLL")
        end
    })

    table.insert(tests, {
        name = "evc3 end-to-end dry-run honors entry point specified in add_ldflags",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_evc3_ldflag_entry")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/main.c"), "int custom_main() { return 0; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("flag_entry_app")
    set_kind("binary")
    add_rules("forge.evc3", {override = true})
    add_ldflags("/entry:custom_main")
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "wince", "-a", "arm"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("/entry:custom_main") ~= nil, "dry-run must pass /entry:custom_main from ldflags")
            T.assert_nil(out:find("WinMainCRTStartup"), "dry-run must not inject WinMainCRTStartup when ldflags has entry")
        end
    })

    table.insert(tests, {
        name = "watcom compiler flags dry-run maps optimization, symbols and warnings",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_watcom_flags")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/main.c"), "int main() { return 0; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("dos_flags_app")
    set_kind("binary")
    add_rules("forge.watcom", {override = true})
    set_optimize("none")
    set_symbols("debug")
    set_warnings("all")
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "dos", "-a", "i386"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("%-O0") ~= nil, "dry-run must map optimize 'none' to -O0")
            T.assert_true(out:find("%-g2") ~= nil, "dry-run must map symbols 'debug' to -g2")
            T.assert_true(out:find("%-Wextra") ~= nil, "dry-run must map warnings 'all' to -Wextra")
        end
    })

    table.insert(tests, {
        name = "evc3 compiler flags dry-run maps optimization, symbols and warnings",
        func = function ()
            local tmp = path.join(os.tmpdir(), "forge_test_evc3_flags")
            os.mkdir(tmp)
            os.mkdir(path.join(tmp, "src"))
            io.writefile(path.join(tmp, "src/main.c"), "int main() { return 0; }")
            io.writefile(path.join(tmp, "xmake.lua"), string.format([[
includes("%s/includes/forge.lua")
target("evc3_flags_app")
    set_kind("binary")
    add_rules("forge.evc3", {override = true})
    set_optimize("none")
    set_symbols("debug")
    set_warnings("all")
    add_files("src/*.c")
]], os.projectdir()))

            local old_dir = os.cd(tmp)
            os.execv("xmake", {"f", "-p", "wince", "-a", "arm"})
            local out = os.iorunv("xmake", {"b", "-v", "--dry-run"})
            os.cd(old_dir)
            os.rm(tmp)

            T.assert_true(out:find("/Od") ~= nil, "dry-run must map optimize 'none' to /Od")
            T.assert_true(out:find("/Z7") ~= nil, "dry-run must map symbols 'debug' to /Z7")
            T.assert_true(out:find("/W4") ~= nil, "dry-run must map warnings 'all' to /W4")
        end
    })

    return tests
end
