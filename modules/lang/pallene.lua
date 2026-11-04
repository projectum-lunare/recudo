-- Projectum Lunare Recudo - Pallene Language Support Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local base = import("lang.base", {rootdir = path.directory(os.scriptdir())})

find_program = function (opt) return base.find_program(opt, "pallenec", "pallene") end
program = find_program
search_envs = base.search_envs
dedent = base.dedent

function emit(target)
    local e = target:values("recudo.lang.pallene.emit")
    if e then
        return e:lower()
    end
    if target:is_binary() or target:is_static() or target:is_shared() then
        if not target:data("recudo.lua.is_app") and not target:rule("recudo.lua.app") then
            return "c"
        end
    end
    return "lua"
end

function test(package, expr, opt)
    return base.test(package, {
        program = find_program(package),
        version_arg = "--help",
        default_expr = "local m = {}\nfunction m.f(): integer return 42 end\nreturn m\n",
        expr = expr,
        opt = opt,
    })
end
