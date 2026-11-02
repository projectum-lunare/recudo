-- Projectum Lunare Recudo - Test Runner
-- Simple, zero-dependency unit test runner for xmake Lua

local total_tests = 0
local passed_tests = 0
local failed_tests = 0

-- Global assertion helpers passed to test cases
local T = {}

function T.assert_equal(actual, expected, msg)
    if actual ~= expected then
        local err = string.format("Expected %s (%s), but got %s (%s)%s",
            tostring(expected), type(expected),
            tostring(actual), type(actual),
            msg and (" - " .. msg) or "")
        raise(err)
    end
end

function T.assert_true(val, msg)
    if val ~= true then
        raise("Expected true, got " .. tostring(val) .. (msg and (" - " .. msg) or ""))
    end
end

function T.assert_false(val, msg)
    if val ~= false then
        raise("Expected false, got " .. tostring(val) .. (msg and (" - " .. msg) or ""))
    end
end

function T.assert_not_nil(val, msg)
    if val == nil then
        raise("Expected non-nil value" .. (msg and (" - " .. msg) or ""))
    end
end

function T.assert_nil(val, msg)
    if val ~= nil then
        raise("Expected nil, got " .. tostring(val) .. (msg and (" - " .. msg) or ""))
    end
end

function T.assert_match(str, pattern, msg)
    if not tostring(str):find(pattern) then
        raise(string.format("String %q did not match pattern %q%s",
            tostring(str), pattern, msg and (" - " .. msg) or ""))
    end
end

function T.assert_contains(tbl, item, msg)
    local found = false
    for _, v in ipairs(tbl) do
        if v == item then found = true; break end
    end
    if not found then
        raise(string.format("Table did not contain item %q%s",
            tostring(item), msg and (" - " .. msg) or ""))
    end
end

local function run_suite(filepath, test_dir)
    local filename = path.filename(filepath)
    local suitename = path.basename(filename)
    cprint("\n${bright cyan}==> Running suite:${clear} ${bright white}%s${clear}", filename)

    local mod, load_err
    try {
        function ()
            mod = import(suitename, {rootdir = test_dir, anonymous = true})
        end,
        catch {
            function (err)
                load_err = err
            end
        }
    }

    if not mod then
        cprint("  ${bright red}[LOAD ERROR]${clear} Failed to load suite: %s", tostring(load_err or "unknown error"))
        failed_tests = failed_tests + 1
        return
    end

    local test_list = {}
    if mod.main then
        test_list = mod.main(T) or {}
    elseif mod.tests then
        test_list = mod.tests
    end

    for _, t in ipairs(test_list) do
        total_tests = total_tests + 1
        local t_name = t.name or "unnamed test"
        local start = os.mclock()
        local test_ok = true
        local test_err = nil

        try {
            function ()
                t.func()
            end,
            catch {
                function (err)
                    test_ok = false
                    test_err = tostring(err)
                end
            }
        }

        local elapsed = os.mclock() - start

        if test_ok then
            passed_tests = passed_tests + 1
            cprint("  ${bright green}✓ PASS${clear} %-52s ${dim}(%.1fms)${clear}", t_name, elapsed)
        else
            failed_tests = failed_tests + 1
            cprint("  ${bright red}✗ FAIL${clear} %-52s ${dim}(%.1fms)${clear}", t_name, elapsed)
            cprint("         ${red}%s${clear}", test_err)
        end
    end
end

function main(...)
    local args = {...}
    local projdir = os.projectdir()
    local test_dir = path.join(projdir, "tests")

    cprint("${bright magenta}╔══════════════════════════════════════════════════════════════════════════════╗")
    cprint("${bright magenta}║${bright yellow}                 Projectum Lunare Recudo - Test Suite                          ${bright magenta}║")
    cprint("${bright magenta}╚══════════════════════════════════════════════════════════════════════════════╝${clear}")

    local test_files = os.files(path.join(test_dir, "test_*.lua"))
    table.sort(test_files)

    local target_filter = nil
    if #args > 0 and args[1] and #args[1] > 0 then
        target_filter = args[1]
    end

    for _, f in ipairs(test_files) do
        if not target_filter or path.filename(f):find(target_filter, 1, true) then
            run_suite(f, test_dir)
        end
    end

    cprint("\n${bright green}══════════════════════════════════════════════════════════════════════════════")
    local fail_str = (failed_tests > 0) and ("${bright red}" .. failed_tests) or "${dim}0"
    cprint("${bright yellow}TEST SUMMARY:${clear} Total: ${bright white}%d${clear} | Passed: ${bright green}%d${clear} | Failed: %s${clear}",
        total_tests,
        passed_tests,
        fail_str
    )
    cprint("${bright green}══════════════════════════════════════════════════════════════════════════════${clear}\n")

    if failed_tests > 0 then
        os.exit(1)
    end
end
