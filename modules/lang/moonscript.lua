-- Projectum Lunare Recudo - MoonScript Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt, prog) return base.find_program(opt, prog or "moonc", "moonscript") end
find_compiler = function (opt) return find_program(opt, "moonc") end
find_runner = function (opt) return find_program(opt, "moon") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function test(package, expr, opt)
    local runner = find_runner(package)
    local compiler = find_compiler(package)
    return base.test(package, {
        program = runner or compiler,
        version_arg = "-v",
        eval_arg = runner and "-e" or nil,
        default_expr = [[
            x = 10
            assert x == 10
        ]],
        expr = expr,
        opt = opt,
    })
end
