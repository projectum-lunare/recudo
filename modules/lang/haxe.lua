-- Projectum Lunare Recudo - Haxe Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "haxe", "haxe") end
find_haxelib = function (opt) return base.find_program(opt, "haxelib", "haxe") end
program = find_program
dedent = base.dedent

function backend(target)
    local b = target:values("recudo.lang.haxe.backend")
    if b then
        return b:lower()
    end
    if target:data("recudo.lua.is_app")
        or (target.rule and (target:rule("recudo.lua.app") or target:rule("recudo.lua.module") or target:rule("recudo.lua.binary"))) then
        return "lua"
    end
    if target:is_binary() or target:is_static() or target:is_shared() then
        return "cpp"
    end
    return "lua"
end

function search_envs(package)
    local envs = base.search_envs(package)

    local instdir = package.installdir and package:installdir()
    if not instdir and package.pkg then
        local hpkg = package:pkg("haxe")
        if hpkg and hpkg.installdir then
            instdir = hpkg:installdir()
        end
    end
    if instdir then
        for _, sub in ipairs({"std", "share/haxe/std", "lib/haxe/std"}) do
            local p = path.join(instdir, sub)
            if os.isdir(p) then
                envs.HAXE_STD_PATH = p
                break
            end
        end
    end

    if not envs.HAXE_STD_PATH then
        local haxe_bin = find_program(package)
        if haxe_bin then
            local candidate = path.join(path.directory(path.directory(haxe_bin)), "std")
            if os.isdir(candidate) then
                envs.HAXE_STD_PATH = candidate
            end
        end
    end

    local haxelib_bin = find_haxelib(package)
    if haxelib_bin then
        local bindir = path.directory(haxelib_bin)
        local cur = envs.PATH or os.getenv("PATH")
        if not cur:find(bindir, 1, true) then
            envs.PATH = bindir .. path.envsep() .. cur
        end
    end

    if package and package.pkg then
        local hxcpp_pkg = package:pkg("hxcpp")
        if hxcpp_pkg and hxcpp_pkg.installdir then
            local bindir = hxcpp_pkg:installdir("bin")
            if bindir and os.isdir(bindir) then
                local cur = envs.PATH or os.getenv("PATH")
                if not cur:find(bindir, 1, true) then
                    envs.PATH = bindir .. path.envsep() .. cur
                end
            end
        end
    end

    return envs
end

function build_argv(target, sourcefiles, out)
    local b = backend(target)
    local argv = {}

    -- 1. Check for .hxml files first
    local hxml_file = target:values("recudo.lang.haxe.hxml")
    if not hxml_file then
        for _, src in ipairs(table.wrap(sourcefiles)) do
            if src:endswith(".hxml") then
                hxml_file = src
                break
            end
        end
    end

    if hxml_file then
        table.insert(argv, path(hxml_file))
        return argv
    end

    -- 2. Classpaths (-cp)
    local cps = {}
    local custom_cps = target:values("recudo.lang.haxe.classpaths")
    if custom_cps then
        for _, cp in ipairs(table.wrap(custom_cps)) do
            table.insert(cps, cp)
        end
    else
        for _, src in ipairs(table.wrap(sourcefiles)) do
            if src:endswith(".hx") then
                local dir = path.directory(src)
                if dir and dir ~= "" and dir ~= "." and not table.contains(cps, dir) then
                    table.insert(cps, dir)
                end
            end
        end
        if #cps == 0 then
            if os.isdir("src") then
                table.insert(cps, "src")
            end
            table.insert(cps, ".")
        end
    end

    for _, cp in ipairs(cps) do
        table.insert(argv, "-cp")
        table.insert(argv, path(cp))
    end

    -- 3. Main entry point or classes
    local main = target:values("recudo.lang.haxe.main")
    if not main then
        for _, src in ipairs(table.wrap(sourcefiles)) do
            if path.basename(src) == "Main" then
                main = "Main"
                break
            end
        end
    end
    if main then
        table.insert(argv, "-main")
        table.insert(argv, main)
    else
        for _, src in ipairs(table.wrap(sourcefiles)) do
            if src:endswith(".hx") then
                table.insert(argv, path.basename(src))
            end
        end
    end

    -- 4. Target-specific defines
    if b == "lua" then
        local lua_ver = target:values("recudo.lang.haxe.lua_version")
        local is_luajit = target:values("recudo.lang.haxe.luajit")
        if not lua_ver and not is_luajit then
            local lpkg = target:pkg("luajit") or target:pkg("openresty-luajit")
            if lpkg then
                is_luajit = true
            else
                lpkg = target:pkg("lua")
                if lpkg and lpkg.version then
                    local v = lpkg:version():shortstr()
                    if v and (v:startswith("5.4") or v:startswith("5.5")) then
                        lua_ver = "5.4"
                    elseif v and v:startswith("5.3") then
                        lua_ver = "5.3"
                    elseif v and v:startswith("5.2") then
                        lua_ver = "5.2"
                    end
                else
                    lua_ver = "5.4"
                end
            end
        end

        if lua_ver then
            table.insert(argv, "-D")
            table.insert(argv, "lua-ver=" .. tostring(lua_ver))
        end

        if is_luajit then
            table.insert(argv, "-D")
            table.insert(argv, "luajit")
        end

        if target:values("recudo.lang.haxe.vanilla") then
            table.insert(argv, "-D")
            table.insert(argv, "lua-vanilla")
        end
    elseif b == "cpp" or b == "c++" then
        table.insert(argv, "-D")
        table.insert(argv, "no-compilation")
    end

    -- 5. Defines (-D key or -D key=val)
    local defines = target:values("recudo.lang.haxe.defines")
    if defines then
        for _, def in ipairs(table.wrap(defines)) do
            table.insert(argv, "-D")
            table.insert(argv, def)
        end
    end

    -- 6. Libraries (-lib name)
    local libs = target:values("recudo.lang.haxe.libs")
    if libs then
        for _, lib in ipairs(table.wrap(libs)) do
            table.insert(argv, "-lib")
            table.insert(argv, lib)
        end
    end

    -- 7. Flags
    local flags = target:values("recudo.lang.haxe.flags")
    if flags then
        for _, flag in ipairs(table.wrap(flags)) do
            table.insert(argv, flag)
        end
    end

    -- 8. Debug mode
    if is_mode("debug") or (target.mode and target:mode() == "debug") then
        table.insert(argv, "-debug")
    end

    -- 9. Backend output parameter
    if out then
        if b == "lua" then
            table.insert(argv, "--lua")
            table.insert(argv, path(out))
        elseif b == "cpp" or b == "c++" then
            table.insert(argv, "--cpp")
            table.insert(argv, path(out))
        elseif b == "js" or b == "javascript" then
            table.insert(argv, "--js")
            table.insert(argv, path(out))
        elseif b == "python" then
            table.insert(argv, "--python")
            table.insert(argv, path(out))
        elseif b == "hl" or b == "hashlink" then
            table.insert(argv, "--hl")
            table.insert(argv, path(out))
        elseif b == "jvm" then
            table.insert(argv, "--jvm")
            table.insert(argv, path(out))
        elseif b == "cs" or b == "csharp" then
            table.insert(argv, "--cs")
            table.insert(argv, path(out))
        end
    end

    return argv
end

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "--version",
        default_expr = 'class Main { static function main() { trace("hello from haxe"); } }',
        expr = expr,
        opt = opt,
        runner = function (prog, envs, code, opt)
            local tmpdir = path.join(os.tmpdir(), "recudo_test_haxe_" .. os.getpid())
            os.rm(tmpdir)
            os.mkdir(tmpdir)
            local main_hx = path.join(tmpdir, "Main.hx")
            local out_lua = path.join(tmpdir, "out.lua")
            local src = base.dedent(code)
            if not src:find("class%s+") then
                src = string.format("class Main {\n    static function main() {\n        %s;\n    }\n}", src)
            end
            io.writefile(main_hx, src)
            local argv = {"-cp", tmpdir, "-main", "Main", "--lua", out_lua}
            os.vrunv(prog, argv, {envs = envs})
            os.rm(tmpdir)
        end
    })
end
