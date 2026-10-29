-- Unit Tests: Vintage Compiler Rules (Watcom & eVC3)

import("modules.sdk", {rootdir = os.projectdir()})

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "watcom rule supports C and C++ extensions",
        func = function ()
            local content = io.readfile("rules/watcom/xmake.lua")
            T.assert_not_nil(content)
            T.assert_true(content:find('%.cpp') ~= nil, "Watcom rule should support .cpp")
            T.assert_true(content:find('%.cc') ~= nil, "Watcom rule should support .cc")
            T.assert_true(content:find('%.cxx') ~= nil, "Watcom rule should support .cxx")
        end
    })

    table.insert(tests, {
        name = "watcom rule does not pass separated -x and c/c++ arguments",
        func = function ()
            local content = io.readfile("rules/watcom/xmake.lua")
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
            local sdkdir = sdk.find("watcom", "WATCOM", {fallbacks = "C:\\WATCOM"})
            if not sdkdir or not os.isdir(sdkdir) then
                return
            end

            local bindir = path.join(sdkdir, "binl64")
            if not os.isdir(bindir) then bindir = path.join(sdkdir, "binl") end
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

            local pathes = {bindir}
            local binw = path.join(sdkdir, "binw")
            if os.isdir(binw) then table.insert(pathes, binw) end
            local binp = path.join(sdkdir, "binp")
            if os.isdir(binp) then table.insert(pathes, binp) end
            if os.getenv("PATH") then table.insert(pathes, os.getenv("PATH")) end

            local envs = {
                WATCOM = sdkdir,
                EDPATH = path.join(sdkdir, "eddat"),
                PATH = table.concat(pathes, path.envsep()),
                INCLUDE = path.join(sdkdir, "h") .. path.envsep() .. path.join(sdkdir, "h/dos")
            }

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
            local content = io.readfile("rules/evc3/xmake.lua")
            T.assert_not_nil(content)
            T.assert_true(content:find('%.cpp') ~= nil, "eVC3 rule should support .cpp")
            T.assert_true(content:find('%.cc') ~= nil, "eVC3 rule should support .cc")
            T.assert_true(content:find('%.cxx') ~= nil, "eVC3 rule should support .cxx")
        end
    })

    table.insert(tests, {
        name = "watcom rule dynamically maps optimization, symbols and warnings",
        func = function ()
            local content = io.readfile("rules/watcom/xmake.lua")
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
            local content = io.readfile("rules/evc3/xmake.lua")
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
            local content = io.readfile("rules/watcom/xmake.lua")
            T.assert_true(content:find('-MMD') ~= nil, "Watcom rule should emit -MMD")
            T.assert_true(content:find('-MF') ~= nil, "Watcom rule should emit -MF")
            T.assert_true(content:find('parse_deps') ~= nil, "Watcom rule should parse depfiles")
            T.assert_true(content:find('batchcmds:add_depfiles') ~= nil, "Watcom rule should register depfiles")
        end
    })

    table.insert(tests, {
        name = "evc3 rule tracks header dependencies recursively",
        func = function ()
            local content = io.readfile("rules/evc3/xmake.lua")
            T.assert_true(content:find('scan_evc3_includes') ~= nil, "eVC3 rule should define recursive include scanner")
            T.assert_true(content:find('batchcmds:add_depfiles') ~= nil, "eVC3 rule should register found headers")
        end
    })

    return tests
end
