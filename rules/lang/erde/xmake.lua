-- Projectum Lunare Recudo - Erde Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.erde")
    set_extensions(".erde")

    on_load(function (target)
        import("lang.base").ensure_package(target, "erde")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "erde",
            ext = ".erde",
            program = import("lang.erde").find_program(target),
            argv = function (outfile)
                local outdir = path.directory(outfile)
                local argv = {"compile", path(sourcefile), "-o", path(outdir), "-f"}
                local erde_target = target:values("recudo.lang.erde.target")
                if erde_target then
                    table.insert(argv, "-t")
                    table.insert(argv, tostring(erde_target))
                end
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".erde", "erde")
    end)
