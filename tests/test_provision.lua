-- Projectum Lunare Recudo - Provisioning Test Suite
-- Exercises the tools/ spec resolution and the modules/provision.lua pipeline
-- against local fixtures (no network access required).

function main(T)
    local tests = {}
    local rootdir = os.projectdir()
    local provision = import("lib.fixture_provision", {rootdir = path.join(rootdir, "tests")})
    local archive = import("utils.archive")

    local function fixture(tag, opts)
        opts = opts or {}
        local dir = path.join(os.tmpdir(), "recudo_fixture_" .. tag)
        os.tryrm(dir)
        local srcdir = path.join(dir, "src")
        os.mkdir(path.join(srcdir, "bin"))
        os.mkdir(path.join(srcdir, "include"))
        io.writefile(path.join(srcdir, "bin", "fake-gcc"), "#!/bin/sh\necho 'fake-gcc " .. (opts.echo or "1.0") .. "'\n")
        io.writefile(path.join(srcdir, "include", "fake.h"), "#define FAKE 1\n")
        local zip = path.join(dir, "fixture.zip")
        archive.archive(zip, ".", {curdir = srcdir, recurse = true})
        local sha = provision.file_sha256(zip)
        T.assert_not_nil(sha, "fixture checksum must be computable")
        return {
            id = "fixture-" .. tag,
            name = "Fixture " .. tag,
            version = opts.version or "1.0",
            aliases = {"fix-" .. tag},
            hosts = opts.hosts,
            dependencies = opts.dependencies,
            default_dir = function () return path.join(dir, "opt") end,
            default_cache = function () return path.join(dir, "cache") end,
            sources = {{url = zip, file = "fixture.zip", sha256 = sha, name = "fixture archive"}},
            permissions = {["bin/*"] = "0755"},
            check_file = "bin/fake-gcc",
            default_binary = "fake-gcc",
            binaries = {["fake-gcc"] = {path = "bin/fake-gcc", desc = "fake compiler"}},
            env = {FAKE_SDK = "{install_dir}", PATH = {"{install_dir}/bin"}},
            test = {command = "fake-gcc", args = {}, expect = opts.expect or ("fake-gcc " .. (opts.echo or "1.0"))},
            _dir = dir,
        }
    end

    table.insert(tests, {
        name = "toolchain packages live as recipes under repository/tools/packages",
        func = function ()
            local pkgs = path.join(rootdir, "repository", "tools", "packages")
            T.assert_true(os.isdir(pkgs), "recudo-tools repository must exist")
            local found = {}
            for _, dir in ipairs(os.dirs(path.join(pkgs, "*", "*")) or {}) do
                found[path.basename(dir)] = true
            end
            for _, id in ipairs({"watcom", "wibo", "amigaos-gcc", "atarist-mintelf", "atarist-mint", "kolibrios-sdk", "vbcc", "evc3"}) do
                T.assert_true(found[id] ~= nil, "missing package recipe: " .. id)
            end
            local fix = fixture("reg")
            provision.register_tool(fix)
            T.assert_not_nil(provision.resolve("fixture-reg"), "fixture id must resolve")
            T.assert_not_nil(provision.resolve("fix-reg"), "fixture alias must resolve")
        end
    })

    table.insert(tests, {
        name = "the tool CLI lists the registered package recipes",
        func = function ()
            local out = os.iorunv("xmake", {"recudo", "tool", "list"}, {curdir = rootdir})
            local text = tostring(out)
            for _, id in ipairs({"watcom", "wibo", "amigaos-gcc", "evc3"}) do
                T.assert_true(text:find(id, 1, true) ~= nil, "missing from tool list: " .. id)
            end
        end
    })

    table.insert(tests, {
        name = "provision installs a fixture archive and passes the smoke test",
        func = function ()
            if os.host() == "windows" then return end
            local spec = fixture("basic")
            local ok, msg = provision.install(spec)
            T.assert_true(ok, msg)
            T.assert_true(msg:find("installed", 1, true) ~= nil, msg)
            T.assert_true(provision.is_installed(spec), "probe must confirm the install")
            T.assert_true(os.isfile(path.join(spec._dir, "opt", ".recudo-provision")), "marker must be written")
            local okt, msgt = provision.test(spec)
            T.assert_true(okt, msgt)
        end
    })

    table.insert(tests, {
        name = "provision rejects corrupted sources with a checksum mismatch",
        func = function ()
            local spec = fixture("badsum")
            spec.sources[1].sha256 = string.rep("0", 64)
            local ok, err
            try {
                function ()
                    provision.install(spec)
                    ok = true
                end,
                catch {
                    function (e)
                        err = tostring(e)
                    end
                }
            }
            T.assert_true(ok ~= true, "install must fail on checksum mismatch")
            T.assert_true(tostring(err):find("Checksum mismatch", 1, true) ~= nil, tostring(err))
        end
    })

    table.insert(tests, {
        name = "provision skips completed installs and honors --force",
        func = function ()
            local spec = fixture("idem")
            local ok1, msg1 = provision.install(spec)
            T.assert_true(ok1, msg1)
            local marker = path.join(spec._dir, "opt", ".recudo-provision")
            local first = io.readfile(marker)
            local ok2, msg2 = provision.install(spec)
            T.assert_true(ok2, msg2)
            T.assert_true(msg2:find("already installed", 1, true) ~= nil, msg2)
            T.assert_equal(io.readfile(marker), first, "marker must not change on skip")
            local ok3, msg3 = provision.install(spec, {force = true})
            T.assert_true(ok3, msg3)
            T.assert_true(msg3:find("already installed", 1, true) == nil, msg3)
        end
    })

    table.insert(tests, {
        name = "provision installs declared dependencies before the tool",
        func = function ()
            local dep = fixture("dep")
            provision.register_tool(dep)
            local main = fixture("main", {dependencies = {"fixture-dep"}, echo = "3.0"})
            local ok, msg = provision.install(main)
            T.assert_true(ok, msg)
            T.assert_true(provision.is_installed(dep), "dependency must be installed first")
            T.assert_true(provision.is_installed(main), "main tool must be installed after")
        end
    })

    table.insert(tests, {
        name = "provision smoke test fails cleanly on unexpected output",
        func = function ()
            if os.host() == "windows" then return end
            local spec = fixture("mismatch", {expect = "WONT-MATCH"})
            local ok = provision.install(spec)
            T.assert_true(ok, "install must succeed before the smoke test")
            local okt, msgt = provision.test(spec)
            T.assert_false(okt, "smoke test must fail on unexpected output")
            T.assert_true(tostring(msgt):find("expected", 1, true) ~= nil, msgt)
        end
    })

    table.insert(tests, {
        name = "provision skips hosts outside the spec without failing",
        func = function ()
            if os.host() == "windows" then return end
            local spec = fixture("hostfilter", {hosts = {"windows"}})
            local ok, msg = provision.install(spec)
            T.assert_false(ok, "install must report a skip, not success")
            T.assert_true(msg:find("not needed", 1, true) ~= nil, msg)
        end
    })

    table.insert(tests, {
        name = "every toolchain recipe is well formed and reachable",
        func = function ()
            local pkgs = path.join(rootdir, "repository", "tools", "packages")
            local expected = {
                "amigaos-gcc", "atarist-mintelf", "atarist-mint",
                "evc3", "kolibrios-sdk", "vbcc", "watcom", "wibo",
            }
            local seen = {}
            for _, dir in ipairs(os.dirs(path.join(pkgs, "*", "*")) or {}) do
                local id = path.basename(dir)
                seen[id] = true
                local recipe = path.join(dir, "xmake.lua")
                T.assert_true(os.isfile(recipe), "missing recipe: " .. id)

                local body = io.readfile(recipe) or ""
                T.assert_true(body:find('package("' .. id .. '")', 1, true) ~= nil,
                    id .. ": package() name must match its directory")

                local urls = 0
                for _ in body:gmatch("add_urls%(") do urls = urls + 1 end
                local versions = 0
                for _ in body:gmatch("add_versions%(") do versions = versions + 1 end
                T.assert_true(urls >= 1, id .. ": declares no add_urls")
                T.assert_true(versions >= 1, id .. ": declares no add_versions")

                T.assert_true(body:find("on_install", 1, true) ~= nil, id .. ": no on_install")
                T.assert_true(body:find("on_test", 1, true) ~= nil, id .. ": no on_test")
                T.assert_true(body:find("addenv", 1, true) ~= nil, id .. ": exports no environment")
            end
            for _, id in ipairs(expected) do
                T.assert_true(seen[id] ~= nil, "toolchain recipe missing: " .. id)
            end
        end
    })

    return tests
end
