-- Projectum Lunare Recudo - Pluto Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "pluto", "pluto") end
find_compiler = function (opt) return base.find_program(opt, "plutoc", "pluto") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "-v",
        eval_arg = "-e",
        default_expr = 'class Foo end; print("hello from pluto")',
        expr = expr,
        opt = opt,
    })
end
