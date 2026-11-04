-- Projectum Lunare Recudo - Nelua Systems Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.nelua")
    add_deps("c", "c++")
    set_extensions(".nelua")

    on_load(function (target)
        import("lang.base").ensure_package(target, "nelua")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        local nelua = import("lang.nelua")
        local nelua_prog = nelua.find_program(target)
        local generator = target:values("recudo.lang.nelua.generator") or "c"

        if generator == "lua" then
            import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
                lang = "nelua",
                ext = ".nelua",
                program = nelua_prog,
                argv = function (outfile)
                    return {"-g", "lua", "-c", path(sourcefile), "-o", path(outfile)}
                end
            })
        else
            import("lang.base").build_native(target, batchcmds, sourcefile, opt, {
                lang = "nelua",
                ext = ".nelua",
                program = nelua_prog,
                argv = function (sourcefile_c)
                    return nelua.build_c_argv(target, sourcefile, sourcefile_c)
                end
            })
        end
    end)
