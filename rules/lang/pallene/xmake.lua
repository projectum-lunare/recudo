-- Projectum Lunare Recudo - Pallene Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.pallene")
    set_extensions(".pln")

    on_load(function (target)
        import("lang.base").ensure_package(target, "pallene")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        local pallene = import("lang.pallene")
        local base = import("lang.base")
        local pallenec_prog = pallene.find_program(target)
        local mode = pallene.emit(target)
        local envs = pallene.search_envs(target)

        if mode == "c" then
            base.build_transpiled(target, batchcmds, sourcefile, opt, {
                lang = "pallene",
                ext = ".pln",
                program = pallenec_prog,
                envs = envs,
                argv = function (outfile)
                    return {path(sourcefile), "--emit-c"}
                end
            })
        else
            base.build_transpiled(target, batchcmds, sourcefile, opt, {
                lang = "pallene",
                ext = ".pln",
                program = pallenec_prog,
                envs = envs,
                argv = function (outfile)
                    return {path(sourcefile), "--emit-lua"}
                end
            })
        end
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".pln", "pallene")
    end)
