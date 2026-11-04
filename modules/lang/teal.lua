-- Projectum Lunare Recudo - Teal Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "tl", {"tl", "teal"}) end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "--version",
        runner = function (prog, envs, code, options)
            local tmp = path.join(os.tmpdir(), "test_" .. os.getpid() .. ".tl")
            io.writefile(tmp, base.dedent(code))
            local ok, errors = os.execv(prog, {"check", tmp}, {envs = envs})
            if ok == 0 then
                os.execv(prog, {"run", tmp}, {envs = envs})
            end
            os.rm(tmp)
            if ok ~= 0 then
                raise("tl check failed: " .. tostring(errors))
            end
        end,
        default_expr = "local x: number = 10\nassert(x == 10)",
        expr = expr,
        opt = opt,
    })
end
