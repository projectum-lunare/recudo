-- Projectum Lunare Recudo - PureScript Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.purescript")
    set_extensions(".purs")

    on_load(function (target)
        import("lang.base").ensure_package(target, "purescript")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "purescript",
            ext = ".purs",
            program = import("lang.purescript").find_program(target),
            argv = function (outfile)
                local outdir = path.directory(outfile)
                local argv = {"compile", path(sourcefile), "-o", path(outdir)}
                local codegen = target:values("recudo.lang.purescript.codegen")
                if codegen then
                    table.insert(argv, "--codegen")
                    table.insert(argv, tostring(codegen))
                end
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".purs", "purescript")
    end)
