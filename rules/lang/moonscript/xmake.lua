-- Projectum Lunare Recudo - MoonScript Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.moonscript")
    set_extensions(".moon")

    on_load(function (target)
        import("lang.base").ensure_package(target, "moonscript")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "moonscript",
            ext = ".moon",
            program = import("lang.moonscript").find_compiler(target),
            argv = function (outfile)
                local argv = {}
                if target:values("recudo.lang.moonscript.correlate") then
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
        import("lang.base").install_transpiled(target, ".moon", "moonscript")
    end)
