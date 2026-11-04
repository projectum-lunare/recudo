-- Projectum Lunare Recudo - Fennel Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.fennel")
    set_extensions(".fnl")

    on_load(function (target)
        import("lang.base").ensure_package(target, "fennel")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "fennel",
            ext = ".fnl",
            stdout = true,
            program = import("lang.fennel").find_program(target),
            argv = function (outfile)
                local argv = {"--compile"}
                if target:values("recudo.lang.fennel.correlate") then
                    table.insert(argv, "--correlate")
                end
                if target:values("recudo.lang.fennel.require_as_include") then
                    table.insert(argv, "--require-as-include")
                end
                table.insert(argv, path(sourcefile))
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".fnl", "fennel")
    end)
