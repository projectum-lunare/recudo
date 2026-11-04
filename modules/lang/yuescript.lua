-- Projectum Lunare Recudo - YueScript Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "yue", "yuescript") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "-v",
        eval_arg = "-e",
        default_expr = [[
            add = (a, b) -> a + b
            assert add(10, 20) == 30
            yue = require "yue"
            assert yue.version
            res = yue.to_lua "x = 123"
            assert res\find "123"
        ]],
        expr = expr,
        opt = opt,
    })
end
