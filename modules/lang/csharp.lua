-- Projectum Lunare Recudo - C# Language Support Module (CSharp.lua)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "csharp-lua", "csharp-lua") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "",
        default_expr = 'using System; class Program { static void Main() { Console.WriteLine("hello from csharp"); } }',
        expr = expr,
        opt = opt,
    })
end
