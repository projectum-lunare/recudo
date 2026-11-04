-- Projectum Lunare Recudo - Nelua Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "nelua", "nelua") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function build_c_argv(target, sourcefile, sourcefile_c)
    local argv = {"-c"}
    if is_mode("release") or (target.mode and target:mode() == "release") then
        table.insert(argv, "-r")
    end
    if target:values("recudo.lang.nelua.maximum_performance") then
        table.insert(argv, "-M")
    end
    local defines = target:values("recudo.lang.nelua.defines")
    for _, def in ipairs(table.wrap(defines)) do
        table.insert(argv, "-D" .. def)
    end
    local pragmas = target:values("recudo.lang.nelua.pragmas")
    for _, pragma in ipairs(table.wrap(pragmas)) do
        table.insert(argv, "-P" .. pragma)
    end
    table.insert(argv, path(sourcefile))
    table.insert(argv, "-o")
    table.insert(argv, path(sourcefile_c))
    return argv
end

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "-v",
        runner = function (prog, envs, code, options)
            local tmp = path.join(os.tmpdir(), "test_" .. os.getpid() .. ".nelua")
            local out_c = path.join(os.tmpdir(), "test_" .. os.getpid() .. ".c")
            io.writefile(tmp, base.dedent(code))
            local ok, errors = os.execv(prog, {"-c", tmp, "-o", out_c}, {envs = envs})
            os.rm(tmp)
            if os.isfile(out_c) then
                os.rm(out_c)
            end
            if ok ~= 0 then
                raise("nelua compile failed: " .. tostring(errors))
            end
        end,
        default_expr = "print 'hello from nelua'",
        expr = expr,
        opt = opt,
    })
end
