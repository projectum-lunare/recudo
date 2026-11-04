-- Projectum Lunare Recudo - TypeScript Language Support Module (TypeScriptToLua)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "tstl", "typescript-to-lua") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "--version",
        default_expr = 'console.log("hello from typescript");',
        expr = expr,
        opt = opt,
    })
end
