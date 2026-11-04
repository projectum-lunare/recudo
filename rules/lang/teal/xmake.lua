-- Projectum Lunare Recudo - Teal Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.teal")
    set_extensions(".tl")

    on_load(function (target)
        import("lang.base").ensure_package(target, "tl", {"tl", "teal"})
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "teal",
            ext = ".tl",
            program = import("lang.teal").find_program(target),
            argv = function (outfile)
                local argv = {"gen"}
                if target:values("recudo.lang.teal.check") ~= false then
                    table.insert(argv, "-c")
                end
                table.insert(argv, "-o")
                table.insert(argv, path(outfile))
                table.insert(argv, path(sourcefile))
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".tl", "teal")
    end)
